#!/usr/bin/env python3
"""
Agent STT - Segments, Turns and Speakers

Streams 16 kHz audio to the Speechmatics Agent STT service and prints what a voice agent
gets back: segments, the speech and turn events around them, and speaker labels.

Run with:
    python main.py                # the bundled sample, service VAD closes turns
    python main.py --mic          # your microphone
    python main.py --external     # close turns here with finalize(), using Silero VAD or VAD of your choosing
    python main.py --speakers     # also fetch reusable voiceprints
"""

import argparse
import asyncio
import os
import wave
from collections import Counter
from pathlib import Path

from dotenv import load_dotenv

from speechmatics.agent_stt import (
    AgentSttAsyncClient,
    ClientMessageType,
    Microphone,
    ServerMessageType,
    SpeakerDiarizationConfig,
    TranscriptionConfig,
    TurnConfig,
    TurnDetectionMode,
)

load_dotenv()

# The service takes 16 kHz raw PCM only. Silero reads 512-sample windows at that rate,
# which is exactly one frame here, so a frame can go to both without rebuffering.
SAMPLE_RATE = 16000
FRAME_BYTES = 1024
VAD_WINDOW = 512

DEFAULT_AUDIO = Path(__file__).parent.parent / "assets" / "sample.wav"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("audio", nargs="?", default=str(DEFAULT_AUDIO), help="16 kHz mono 16-bit WAV file")
    parser.add_argument("--mic", action="store_true", help="read the microphone instead (needs pyaudio)")
    parser.add_argument("--external", action="store_true", help="close turns here with finalize() (needs silero-vad)")
    parser.add_argument("--min-silence", type=int, default=500, help="ms of silence that ends a turn (--external)")
    parser.add_argument("--speakers", action="store_true", help="fetch each speaker's reusable voiceprint")
    parser.add_argument("--language", default="en", help="transcription language (default: en)")
    parser.add_argument("--no-partials", action="store_true", help="only show finalized segments")
    return parser.parse_args()


def register_handlers(client: AgentSttAsyncClient) -> None:
    """One handler per message, registered before the session opens.

    Handlers are plain synchronous callbacks, so they must not block: anything slow belongs
    on a queue or in a thread, or it stalls the audio being sent.
    """

    @client.on(ServerMessageType.ADD_PARTIAL_SEGMENT)
    def on_partial(message):
        # An interim preview. Each one replaces the previous, so never concatenate them.
        print(f"[partial] {message['segment']['transcript']}")

    @client.on(ServerMessageType.ADD_SEGMENT)
    def on_segment(message):
        # The finalized segment, and the stable text to pass to an LLM. A turn usually
        # produces several: a segment also ends on a speaker change or a duration cap.
        segment = message["segment"]
        print(f"[final]   {segment.get('speaker') or '--'}: {segment['transcript']}")

    # Voice activity only, and sent in vad mode alone. A pause mid-sentence produces
    # SpeechEnded while the turn stays open, so these are for interruption handling and UI
    # feedback - not for deciding that the speaker has finished.
    @client.on(ServerMessageType.SPEECH_STARTED)
    def on_speech_started(message):
        print(f"[speech]  start at {message['metadata']['start_time']:.2f}s")

    @client.on(ServerMessageType.SPEECH_ENDED)
    def on_speech_ended(message):
        print(f"[speech]  end at {message['metadata']['end_time']:.2f}s")

    # StartOfTurn fires on the first word rather than the first sound, so a cough does not
    # open a turn. EndOfTurn is always the turn's last message: that is when to respond.
    @client.on(ServerMessageType.START_OF_TURN)
    def on_turn_start(message):
        print(f"[turn]    start at {message['metadata']['start_time']:.2f}s")

    @client.on(ServerMessageType.END_OF_TURN)
    def on_turn_end(message):
        print(f"[turn]    end at {message['metadata']['end_time']:.2f}s")

    # The reply to GetSpeakers. Store these and pass them back as
    # speaker_diarization_config.speakers to recognize the same person in a later session.
    @client.on(ServerMessageType.SPEAKERS_RESULT)
    def on_speakers(message):
        for speaker in message.get("speakers") or []:
            identifiers = speaker.get("speaker_identifiers") or []
            preview = identifiers[0][:40] + "..." if identifiers else "(none)"
            print(f"[speaker] {speaker.get('label', '?')}  {preview}")

    @client.on(ServerMessageType.ERROR)
    def on_error(message):
        print(f"[error]   {message.get('reason', message)}")


async def audio_frames(args: argparse.Namespace):
    """Yield 16 kHz PCM frames, from the microphone or from a file at real-time speed."""
    if args.mic:
        mic = Microphone(sample_rate=SAMPLE_RATE, chunk_size=FRAME_BYTES)
        if not mic.is_available:
            raise SystemExit("PyAudio not installed - install it with: pip install pyaudio")
        if not mic.start():
            raise SystemExit("Could not open the microphone - check an input device is free")
        print("Microphone ready - speak now (Ctrl+C to stop)\n")
        try:
            while True:
                yield await mic.read(FRAME_BYTES)
        finally:
            mic.stop()
        return

    with wave.open(args.audio, "rb") as wav:
        if (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) != (SAMPLE_RATE, 1, 2):
            raise SystemExit(
                f"{args.audio} is {wav.getframerate()} Hz, {wav.getnchannels()} channel(s). "
                f"The service needs 16 kHz mono 16-bit PCM:\n"
                f"  ffmpeg -i {args.audio} -ar 16000 -ac 1 -sample_fmt s16 converted.wav"
            )
        print(f"Streaming {wav.getnframes() / SAMPLE_RATE:.1f}s of audio\n")

        started_at = asyncio.get_running_loop().time()
        sent_seconds = 0.0
        while frame := wav.readframes(FRAME_BYTES // 2):
            yield frame

            # Hold the next frame until the wall clock catches up with the audio already
            # sent, so the recording streams at real time and the service's VAD sees its
            # real pauses. Paced against the session clock rather than one sleep per frame,
            # which drifts by however long each send and VAD call took.
            sent_seconds += len(frame) / (SAMPLE_RATE * 2)
            ahead = sent_seconds - (asyncio.get_running_loop().time() - started_at)
            if ahead > 0:
                await asyncio.sleep(ahead)


def load_vad(min_silence_ms: int):
    """Silero VAD: the end-of-speech signal that TurnDetectionMode.EXTERNAL needs.

    The service exposes no silence trigger of its own, so `min_silence_duration_ms` here is
    the dial that decides how long a pause has to be before the turn is closed.
    """
    try:
        from silero_vad import VADIterator, load_silero_vad
    except ImportError:
        raise SystemExit("--external needs a VAD: pip install silero-vad torch numpy") from None

    print(f"Loading Silero VAD (turn ends after {min_silence_ms}ms of silence)")
    return VADIterator(load_silero_vad(), sampling_rate=SAMPLE_RATE, min_silence_duration_ms=min_silence_ms)


def speech_ended(vad, frame: bytes) -> bool:
    """True when Silero reports the end of a speech run. Called in a worker thread."""
    import numpy as np
    import torch

    samples = np.frombuffer(frame, dtype=np.int16).astype(np.float32) / 32768.0
    tensor = torch.from_numpy(samples)
    windows = (tensor[i : i + VAD_WINDOW] for i in range(0, len(tensor) - VAD_WINDOW + 1, VAD_WINDOW))
    return any((result := vad(window)) and "end" in result for window in windows)


def summarise(client: AgentSttAsyncClient) -> None:
    """What the client still holds once the session has closed."""
    pack = client.session_info.language_pack_info
    census = Counter(event["message"] for event in client.events)

    print(f"\nSession   {client.session_info.session_id}  |  {pack.language_description}")
    print("Messages  " + ", ".join(f"{count} {name}" for name, count in census.most_common()))
    print(f"Timeline  {len(client.timeline)} speech and turn events")

    print(f"\nSegments ({len(client.segments)})")
    for segment in client.segments:
        speaker = segment.speaker or "--"
        print(f"  {segment.start_time:6.2f}s - {segment.end_time:6.2f}s  {speaker:>3}  {segment.transcript}")

    print(f"\nTranscript\n  {client.transcript or '(no speech recognized)'}")


async def main() -> None:
    args = parse_args()

    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    vad = load_vad(args.min_silence) if args.external else None

    client = AgentSttAsyncClient(
        url="wss://global.rt.speechmatics.com/v2",
        api_key=api_key,
        # The familiar real-time config, with this service's own model names. `model`
        # defaults to Model.LINDEN_1, so it does not need setting.
        transcription_config=TranscriptionConfig(
            language=args.language,
            enable_partials=not args.no_partials,
            diarization="speaker",
            speaker_diarization_config=SpeakerDiarizationConfig(prefer_current_speaker=True),
        ),
        # Turn taking is a separate config, and fixed for the life of the session.
        turn_config=TurnConfig(
            turn_detection_mode=TurnDetectionMode.EXTERNAL if args.external else TurnDetectionMode.VAD
        ),
        app="speechmatics-academy/agent-stt",
    )
    register_handlers(client)

    print(f"Turns closed by {'this script, via finalize()' if args.external else 'the service'}\n")

    # Entering waits until the service is ready for audio; leaving sends EndOfStream and
    # waits for the service to flush whatever it still holds.
    async with client:
        async for frame in audio_frames(args):
            await client.send_audio(frame)

            # Silero is synchronous, so it runs in a thread: inline it and the inference
            # blocks the event loop that is meant to be sending audio.
            if vad is not None and await asyncio.to_thread(speech_ended, vad, frame):
                print("[vad]     speech ended -> finalize()")
                await client.force_end_of_utterance()

        if args.speakers:
            # Only answered while the session is open, so ask before leaving.
            await client.send_message({"message": ClientMessageType.GET_SPEAKERS})
            await asyncio.sleep(2)

    summarise(client)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
