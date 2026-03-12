"""
Voice API Explorer

Comprehensive demo of the Speechmatics Voice API — a unified WebSocket
endpoint for both real-time transcription (RT) and voice agent (Voice) modes.

Default input is your microphone — speak, press Enter to stop, then demos
replay your recording through each API mode and profile.

Usage:
    python main.py                     # Interactive menu (mic input)
    python main.py rt                  # RT mode transcription
    python main.py rt-translate        # RT mode with translation
    python main.py voice               # Voice mode (adaptive profile)
    python main.py profiles            # Compare all voice profiles
    python main.py advanced            # Speaker focus, ForceEOU, GetSpeakers
    python main.py messages            # Message control include/exclude
    python main.py all                 # Run all demos
    python main.py rt --audio f.wav    # Use a WAV file instead of mic
"""

import argparse
import asyncio
import json
import os
import sys
import wave
from pathlib import Path

from dotenv import load_dotenv
import pyaudio
import websockets

load_dotenv()

# ─── Constants ────────────────────────────────────────────────────────────────

DEFAULT_SERVER = "wss://preview.rt.speechmatics.com"
MIC_SAMPLE_RATE = 16000   # Mic recording sample rate (Hz)
MIC_CHUNK_MS = 20         # Mic callback buffer size (ms)
REPLAY_CHUNK_MS = 100     # Replay chunk size for streaming (ms)
PACING = 4.0              # Replay audio at Nx real-time speed
DEBUG = False             # Set via --debug flag


# ─── Audio Utilities ──────────────────────────────────────────────────────────


def record_audio(sample_rate: int = MIC_SAMPLE_RATE) -> tuple:
    """Record from microphone until Enter is pressed. Returns (pcm, sample_rate).

    Uses PyAudio's callback mode so recording runs in a background thread
    while the main thread blocks on Enter.
    """
    chunk_frames = sample_rate * MIC_CHUNK_MS // 1000
    chunks = []
    recording = True

    def callback(in_data, frame_count, time_info, status):
        if recording:
            chunks.append(in_data)
        return (None, pyaudio.paContinue)

    pa = pyaudio.PyAudio()
    stream = pa.open(
        format=pyaudio.paInt16,
        channels=1,
        rate=sample_rate,
        input=True,
        frames_per_buffer=chunk_frames,
        stream_callback=callback,
    )
    stream.start_stream()

    print("  Recording... speak now, then press Enter to stop.\n")

    try:
        sys.stdin.readline()  # Block until Enter
    except (EOFError, KeyboardInterrupt):
        pass

    recording = False
    stream.stop_stream()
    stream.close()
    pa.terminate()

    pcm = b"".join(chunks)
    duration = len(pcm) / (sample_rate * 2)
    print(f"  Recorded {duration:.1f}s of audio ({sample_rate}Hz, 16-bit mono)")

    if duration < 0.5:
        print("  Warning: Very short recording. Check your microphone is working.")

    return pcm, sample_rate


def read_wav(path: Path) -> tuple:
    """Read a WAV file and return (raw_pcm_bytes, sample_rate).

    Validates that the file is 16-bit mono PCM.
    """
    with wave.open(str(path), "rb") as wf:
        if wf.getsampwidth() != 2:
            raise ValueError(
                f"Expected 16-bit audio, got {wf.getsampwidth() * 8}-bit. "
                "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav"
            )
        if wf.getnchannels() != 1:
            raise ValueError(
                f"Expected mono audio, got {wf.getnchannels()} channels. "
                "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav"
            )
        sample_rate = wf.getframerate()
        pcm = wf.readframes(wf.getnframes())

    duration = len(pcm) / (sample_rate * 2)
    print(f"  Audio: {path.name} ({duration:.1f}s, {sample_rate}Hz, 16-bit mono)")
    return pcm, sample_rate


def iter_chunks(pcm: bytes, sample_rate: int, chunk_ms: int = REPLAY_CHUNK_MS):
    """Yield audio chunks of chunk_ms milliseconds."""
    chunk_bytes = sample_rate * 2 * chunk_ms // 1000  # 2 bytes per sample (16-bit)
    for i in range(0, len(pcm), chunk_bytes):
        yield pcm[i : i + chunk_bytes]


# ─── Session Runner ───────────────────────────────────────────────────────────


async def run_session(
    *,
    api_key: str,
    server: str,
    path: str,
    config: dict,
    pcm: bytes,
    sample_rate: int,
    on_message,
    after_audio_fn=None,
):
    """
    Run a complete Voice API WebSocket session.

    Lifecycle:
      1. Connect with Bearer token auth
      2. Send StartRecognition
      3. Wait for RecognitionStarted
      4. Stream audio as binary frames (paced)
      5. Optionally run after_audio_fn(ws) for mid-session commands
      6. Send EndOfStream
      7. Receive messages until EndOfTranscript
    """
    url = f"{server}{path}"
    headers = {"Authorization": f"Bearer {api_key}"}
    messages = []

    recognition_started = asyncio.Event()
    session_ended = asyncio.Event()

    if DEBUG:
        print(f"  [DEBUG] URL: {url}")

    try:
        async with websockets.connect(
            url,
            additional_headers=headers,
            open_timeout=10,
            ping_interval=20,
            ping_timeout=60,
        ) as ws:
            # Send StartRecognition as the first frame
            start_msg = {"message": "StartRecognition", **config}
            if DEBUG:
                print(f"  [DEBUG] Sending: {json.dumps(start_msg, indent=2)}")
            await ws.send(json.dumps(start_msg))

            async def receiver():
                """Receive and dispatch server messages."""
                async for frame in ws:
                    if isinstance(frame, bytes):
                        continue  # Skip unexpected binary frames
                    try:
                        msg = json.loads(frame)
                    except (json.JSONDecodeError, TypeError):
                        continue

                    msg_type = msg.get("message", "")
                    messages.append(msg)

                    if DEBUG:
                        # Show every message type + truncated raw JSON
                        print(f"  [DEBUG] << {msg_type}: {json.dumps(msg)[:200]}")

                    if msg_type == "RecognitionStarted":
                        recognition_started.set()

                    on_message(msg)

                    if msg_type == "EndOfTranscript":
                        session_ended.set()
                        break

            async def sender():
                """Stream audio, run mid-session actions, send EndOfStream."""
                # Wait for RecognitionStarted before streaming audio
                try:
                    await asyncio.wait_for(recognition_started.wait(), timeout=10.0)
                except asyncio.TimeoutError:
                    print("  [Timeout] RecognitionStarted not received within 10s")
                    return

                # Stream audio chunks at paced rate
                chunk_delay = (REPLAY_CHUNK_MS / 1000) / PACING
                for chunk in iter_chunks(pcm, sample_rate):
                    await ws.send(chunk)
                    await asyncio.sleep(chunk_delay)

                # Mid-session actions (ForceEOU, UpdateSpeakerFocus, etc.)
                if after_audio_fn:
                    await after_audio_fn(ws)

                # Signal end of audio
                eos = {"message": "EndOfStream", "last_seq_no": 0}
                await ws.send(json.dumps(eos))

            await asyncio.gather(receiver(), sender())

    except websockets.exceptions.ConnectionClosedError as e:
        print(f"  [ConnectionClosed] code={e.code} reason={e.reason}")
    except websockets.exceptions.InvalidStatusCode as e:
        print(f"  [ConnectionFailed] HTTP {e.status_code}")
        if e.status_code == 401:
            print("  Check your SPEECHMATICS_API_KEY is valid.")
    except OSError as e:
        print(f"  [NetworkError] {e}")

    return messages


# ─── Message Formatter ────────────────────────────────────────────────────────


# ANSI colour codes
class C:
    RESET   = "\033[0m"
    BOLD    = "\033[1m"
    DIM     = "\033[2m"
    # Foreground
    GREEN   = "\033[32m"     # Finals, Segments, Translations
    YELLOW  = "\033[33m"     # Partials
    CYAN    = "\033[36m"     # Speaker events, Turn events
    MAGENTA = "\033[35m"     # Metrics
    RED     = "\033[31m"     # Errors
    ORANGE  = "\033[38;5;208m"  # Warnings
    BLUE    = "\033[34m"     # Session lifecycle
    WHITE   = "\033[37m"     # Optional / debug messages


# Enable ANSI escape processing on Windows
if sys.platform == "win32":
    os.system("")


# Optional message types — only shown when the demo explicitly opts in
OPTIONAL_MSG_TYPES = {
    "AudioAdded", "SpeechStarted", "SpeechEnded",
    "EndOfTurnPrediction", "SmartTurnPrediction", "Diagnostics",
}


def print_msg(msg: dict, indent: int = 4, show_optional: bool = False):
    """Pretty-print a Voice API server message.

    Optional message types (AudioAdded, SpeechStarted, etc.) are suppressed
    unless show_optional=True — the server may forward them even without
    explicit message_control.include.
    """
    p = " " * indent
    mt = msg.get("message", "unknown")

    if not show_optional and mt in OPTIONAL_MSG_TYPES:
        return

    if mt == "RecognitionStarted":
        sid = msg.get("id", "?")[:20]
        lang = msg.get("language_pack_info", {}).get("language_description", "?")
        ver = msg.get("orchestrator_version", "")
        print(f"{p}{C.BLUE}{C.BOLD}[RecognitionStarted]{C.RESET}{C.BLUE} session={sid}... lang={lang}{C.RESET}")
        if ver:
            print(f"{p}{C.BLUE}  orchestrator: {ver}{C.RESET}")

    elif mt == "AddPartialTranscript":
        text = msg.get("metadata", {}).get("transcript", "")
        if text.strip():
            print(f"{p}{C.YELLOW}[Partial]     {text}{C.RESET}")

    elif mt == "AddTranscript":
        text = msg.get("metadata", {}).get("transcript", "")
        if text.strip():
            results = msg.get("results", [])
            words = [r for r in results if r.get("type") == "word"]
            if words:
                confs = [w["alternatives"][0]["confidence"] for w in words]
                avg = sum(confs) / len(confs)
                print(f"{p}{C.GREEN}{C.BOLD}[Final]       {text}  (avg confidence: {avg:.2f}){C.RESET}")
            else:
                print(f"{p}{C.GREEN}{C.BOLD}[Final]       {text}{C.RESET}")

    elif mt == "AddPartialTranslation":
        lang = msg.get("language", "?")
        text = msg.get("metadata", {}).get("transcript", "")
        if not text:
            results = msg.get("results", [])
            text = " ".join(r.get("content", "") for r in results).strip()
        if text.strip():
            print(f"{p}{C.YELLOW}[PartialTr:{lang}] {text}{C.RESET}")
        else:
            print(f"{p}{C.YELLOW}[PartialTr:{lang}] (raw: {json.dumps(msg)[:120]}){C.RESET}")

    elif mt == "AddTranslation":
        lang = msg.get("language", "?")
        text = msg.get("metadata", {}).get("transcript", "")
        if not text:
            results = msg.get("results", [])
            text = " ".join(r.get("content", "") for r in results).strip()
        if text.strip():
            print(f"{p}{C.GREEN}{C.BOLD}[Translation:{lang}] {text}{C.RESET}")
        else:
            print(f"{p}{C.GREEN}{C.BOLD}[Translation:{lang}] (raw: {json.dumps(msg)[:120]}){C.RESET}")

    elif mt == "AddPartialSegment":
        for seg in msg.get("segments", []):
            text = seg.get("text", "")
            if text.strip():
                spk = seg.get("speaker_id", "?")
                ann = seg.get("annotation", [])
                ann_s = f"  [{', '.join(ann)}]" if ann else ""
                print(f"{p}{C.YELLOW}[PartialSeg]  {spk}: {text}{ann_s}{C.RESET}")

    elif mt == "AddSegment":
        for seg in msg.get("segments", []):
            text = seg.get("text", "")
            spk = seg.get("speaker_id", "?")
            ann = seg.get("annotation", [])
            eou = seg.get("is_eou", False)
            meta = seg.get("metadata", {})
            t0, t1 = meta.get("start_time", 0), meta.get("end_time", 0)
            ann_s = f"  {C.DIM}[{', '.join(ann)}]{C.RESET}" if ann else ""
            eou_s = f" {C.CYAN}(EOU){C.RESET}" if eou else ""
            print(f"{p}{C.GREEN}{C.BOLD}[Segment]     {spk}: {text} ({t0:.2f}-{t1:.2f}s){C.RESET}{ann_s}{eou_s}")

    elif mt == "SpeakerStarted":
        spk = msg.get("speaker_id", "?")
        t = msg.get("metadata", {}).get("start_time", msg.get("time", "?"))
        print(f"{p}{C.CYAN}[SpeakerStarted] {spk} at {t}s{C.RESET}")

    elif mt == "SpeakerEnded":
        spk = msg.get("speaker_id", "?")
        t = msg.get("metadata", {}).get("end_time", msg.get("time", "?"))
        print(f"{p}{C.CYAN}[SpeakerEnded]   {spk} at {t}s{C.RESET}")

    elif mt == "StartOfTurn":
        print(f"{p}{C.CYAN}{C.BOLD}[StartOfTurn]  turn_id={msg.get('turn_id', '?')}{C.RESET}")

    elif mt == "EndOfTurn":
        print(f"{p}{C.CYAN}{C.BOLD}[EndOfTurn]    turn_id={msg.get('turn_id', '?')}{C.RESET}")

    elif mt == "EndOfUtterance":
        meta = msg.get("metadata", {})
        print(f"{p}{C.CYAN}[EndOfUtterance] {meta.get('start_time', '?')}s - {meta.get('end_time', '?')}s{C.RESET}")

    elif mt == "SessionMetrics":
        total = msg.get("total_time_str", msg.get("total_time", "?"))
        proc = msg.get("processing_time", "?")
        byt = msg.get("total_bytes", "?")
        print(f"{p}{C.MAGENTA}[SessionMetrics]  time={total} processing={proc}s bytes={byt}{C.RESET}")

    elif mt == "SpeakerMetrics":
        for spk in msg.get("speakers", []):
            sid = spk.get("speaker_id", "?")
            wc = spk.get("word_count", 0)
            vol = spk.get("volume", 0)
            last = spk.get("last_heard", 0)
            print(f"{p}{C.MAGENTA}[SpeakerMetrics]  {sid}: words={wc} vol={vol:.1f} last={last:.2f}s{C.RESET}")

    elif mt == "SpeakersResult":
        speakers = msg.get("speakers", msg)
        print(f"{p}{C.MAGENTA}[SpeakersResult]  {json.dumps(speakers)[:200]}{C.RESET}")

    elif mt == "AudioAdded":
        seq = msg.get("seq_no", "?")
        print(f"{p}{C.DIM}[AudioAdded]   seq_no={seq}{C.RESET}")

    elif mt == "SpeechStarted":
        t = msg.get("metadata", {}).get("start_time", "?")
        prob = msg.get("probability", "?")
        print(f"{p}{C.WHITE}[SpeechStarted]  at {t}s  probability={prob}{C.RESET}")

    elif mt == "SpeechEnded":
        meta = msg.get("metadata", {})
        prob = msg.get("probability", "?")
        dur = msg.get("transition_duration_ms", "?")
        print(
            f"{p}{C.WHITE}[SpeechEnded]    {meta.get('start_time', '?')}-{meta.get('end_time', '?')}s"
            f"  prob={prob}  transition={dur}ms{C.RESET}"
        )

    elif mt == "EndOfTurnPrediction":
        wait = msg.get("predicted_wait", "?")
        print(f"{p}{C.WHITE}[EndOfTurnPrediction] predicted_wait={wait}s{C.RESET}")

    elif mt == "SmartTurnPrediction":
        print(f"{p}{C.WHITE}[SmartTurnPrediction] {json.dumps(msg)[:140]}{C.RESET}")

    elif mt == "AudioEventStarted":
        etype = msg.get("type", msg.get("event", "?"))
        print(f"{p}{C.CYAN}[AudioEventStarted] type={etype}{C.RESET}")

    elif mt == "AudioEventEnded":
        etype = msg.get("type", msg.get("event", "?"))
        print(f"{p}{C.CYAN}[AudioEventEnded]   type={etype}{C.RESET}")

    elif mt == "Info":
        itype = msg.get("type", "")
        reason = msg.get("reason", "")
        extra = ""
        if msg.get("quality"):
            extra = f" quality={msg['quality']}"
        print(f"{p}{C.BLUE}[Info:{itype}] {reason}{extra}{C.RESET}")

    elif mt == "Warning":
        print(f"{p}{C.ORANGE}{C.BOLD}[Warning] {msg.get('reason', msg.get('type', ''))}{C.RESET}")

    elif mt == "Error":
        print(f"{p}{C.RED}{C.BOLD}[Error] {msg.get('reason', msg.get('type', json.dumps(msg)))}{C.RESET}")

    elif mt == "EndOfTranscript":
        print(f"{p}{C.BLUE}{C.BOLD}[EndOfTranscript] Session complete.{C.RESET}")

    elif mt == "Diagnostics":
        print(f"{p}{C.DIM}[Diagnostics] {json.dumps(msg)[:140]}{C.RESET}")

    else:
        print(f"{p}{C.DIM}[{mt}] {json.dumps(msg)[:140]}{C.RESET}")


# ─── Helpers ──────────────────────────────────────────────────────────────────


def header(title: str):
    print(f"\n{'=' * 80}")
    print(f"  {title}")
    print(f"{'=' * 80}\n")


def subheader(title: str):
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


def audio_format_block(sample_rate: int) -> dict:
    """Standard audio_format config block for raw PCM."""
    return {
        "type": "raw",
        "encoding": "pcm_s16le",
        "sample_rate": sample_rate,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 1: RT Mode — Basic Transcription
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_rt_basic(api_key, server, pcm, sr):
    """RT mode: stream audio via /v2, receive partials and finals."""
    header("Demo 1: RT Mode — Real-Time Transcription")
    print("  Mode:     RT (no profile)")
    print("  Endpoint: /v2")
    print("  Shows:    AddPartialTranscript, AddTranscript, confidence scores,")
    print("            punctuation, EndOfUtterance, RecognitionStarted")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_partials": True,
            "operating_point": "enhanced",
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 2: RT Mode — Translation
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_rt_translate(api_key, server, pcm, sr):
    """RT mode with real-time translation to Spanish and French."""
    header("Demo 2: RT Mode — Real-Time Translation")
    print("  Mode:     RT (no profile)")
    print("  Endpoint: /v2")
    print("  Shows:    translation_config, AddPartialTranslation, AddTranslation")
    print("  Note:     Translation is RT-mode only. Not supported in Voice mode.")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_partials": True,
        },
        "translation_config": {
            "target_languages": ["ru", "fr"],
            "enable_partials": True,
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 3: Voice Mode — Single Profile (adaptive)
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_single(api_key, server, pcm, sr):
    """Voice mode with the adaptive profile — the most versatile option."""
    header("Demo 3: Voice Mode — Adaptive Profile")
    print("  Mode:     Voice")
    print("  Endpoint: /v2/agent/adaptive")
    print("  Shows:    AddPartialSegment, AddSegment, SpeakerStarted/Ended,")
    print("            StartOfTurn, EndOfTurn, SessionMetrics, SpeakerMetrics")
    print()

    config = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 4: Voice Mode — Profile Comparison
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_profiles(api_key, server, pcm, sr):
    """Compare all four voice profiles with the same audio."""
    header("Demo 4: Voice Mode — Profile Comparison")
    print("  Runs the same audio through all four profiles to compare behaviour.")
    print("  Profiles are selected via URL path: /v2/agent/{profile}")
    print("  Versioning is also supported, e.g. /v2/agent/adaptive:latest")
    print()

    profiles = [
        ("agile", "Fastest response, VAD-based turn detection"),
        ("adaptive", "Adapts to speaker pace and disfluency"),
        ("smart", "Acoustic model for turn completion"),
        ("external", "Client-controlled turn detection"),
    ]

    for profile, desc in profiles:
        subheader(f"Profile: {profile} — {desc}")
        print(f"  Endpoint: /v2/agent/{profile}")
        print()

        config = {
            "transcription_config": {
                "language": "en",
            },
            "audio_format": audio_format_block(sr),
        }

        # For external profile, manually trigger end-of-utterance
        after_fn = None
        if profile == "external":

            async def force_eou(ws):
                await asyncio.sleep(0.5)
                print("    >> Sending ForceEndOfUtterance")
                await ws.send(json.dumps({"message": "ForceEndOfUtterance"}))

            after_fn = force_eou

        try:
            await run_session(
                api_key=api_key,
                server=server,
                path=f"/v2/agent/{profile}",
                config=config,
                pcm=pcm,
                sample_rate=sr,
                on_message=print_msg,
                after_audio_fn=after_fn,
            )
        except Exception as e:
            print(f"    [Error] {type(e).__name__}: {e}")

        print()


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 5: Voice Mode — Advanced Features
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_advanced(api_key, server, pcm, sr):
    """Speaker focus, ForceEndOfUtterance, GetSpeakers, and diarization."""
    header("Demo 5: Voice Mode — Advanced Features")
    print("  Features: enable_diarization, UpdateSpeakerFocus, GetSpeakers,")
    print("            ForceEndOfUtterance, SpeakersResult, focus_mode")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_diarization": True,
        },
        "audio_format": audio_format_block(sr),
    }

    async def mid_session_actions(ws):
        """Demonstrate mid-session control messages."""
        # 1. Request speaker identification data
        print()
        print("    >> Sending GetSpeakers")
        await ws.send(json.dumps({"message": "GetSpeakers"}))
        await asyncio.sleep(1.0)

        # 2. Update speaker focus — retain mode (non-focused speakers are passive)
        print("    >> Sending UpdateSpeakerFocus (focus S1, mode=retain)")
        await ws.send(
            json.dumps(
                {
                    "message": "UpdateSpeakerFocus",
                    "speaker_focus": {
                        "focus_speakers": ["S1"],
                        "ignore_speakers": [],
                        "focus_mode": "retain",
                    },
                }
            )
        )
        await asyncio.sleep(0.5)

        # 3. Force end of utterance
        print("    >> Sending ForceEndOfUtterance")
        await ws.send(json.dumps({"message": "ForceEndOfUtterance"}))
        await asyncio.sleep(0.5)

        # 4. Switch to ignore mode (non-focused speakers are dropped entirely)
        print("    >> Sending UpdateSpeakerFocus (focus S1, mode=ignore)")
        await ws.send(
            json.dumps(
                {
                    "message": "UpdateSpeakerFocus",
                    "speaker_focus": {
                        "focus_speakers": ["S1"],
                        "ignore_speakers": [],
                        "focus_mode": "ignore",
                    },
                }
            )
        )
        await asyncio.sleep(0.3)

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
        after_audio_fn=mid_session_actions,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 6: Message Control — Include/Exclude
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_message_control(api_key, server, pcm, sr):
    """Demonstrate message_control to opt in/out of optional message types."""
    header("Demo 6: Message Control — Include/Exclude")

    # ── Part A: Include optional messages ──
    subheader("Part A: Include optional messages")
    print("  AudioAdded, SpeechStarted, SpeechEnded are NOT forwarded by default.")
    print("  Using message_control.include to opt in.")
    print()

    config_include = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
        "message_control": {
            "include": ["AudioAdded", "SpeechStarted", "SpeechEnded"],
        },
    }

    # show_optional=True so AudioAdded/SpeechStarted/SpeechEnded are printed
    def print_with_optional(msg):
        print_msg(msg, show_optional=True)

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config_include,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_with_optional,
    )

    # ── Part B: Exclude default messages ──
    subheader("Part B: Exclude default messages")
    print("  SpeakerMetrics and SessionMetrics are forwarded by default in Voice mode.")
    print("  Using message_control.exclude to opt out.")
    print()

    config_exclude = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
        "message_control": {
            "exclude": ["SpeakerMetrics", "SessionMetrics"],
        },
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/agile",
        config=config_exclude,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# CLI & Main
# ═══════════════════════════════════════════════════════════════════════════════

DEMOS = {
    "rt": ("RT Mode — Transcription", demo_rt_basic),
    "rt-translate": ("RT Mode — Translation", demo_rt_translate),
    "voice": ("Voice Mode — Adaptive Profile", demo_voice_single),
    "profiles": ("Voice Mode — Profile Comparison", demo_voice_profiles),
    "advanced": ("Voice Mode — Advanced Features", demo_voice_advanced),
    "messages": ("Message Control — Include/Exclude", demo_message_control),
}


def show_menu():
    """Display interactive demo selection menu."""
    print()
    print("=" * 60)
    print("  Speechmatics Voice API Explorer")
    print("=" * 60)
    print()
    print("  Select a demo to run:")
    print()
    for i, (key, (title, _)) in enumerate(DEMOS.items(), 1):
        print(f"    {i}. [{key}] {title}")
    print(f"    {len(DEMOS) + 1}. [all] Run all demos")
    print(f"    0. Exit")
    print()

    while True:
        try:
            choice = input("  Enter number or name: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return None

        if choice == "0" or choice == "exit":
            return None
        if choice == "all" or choice == str(len(DEMOS) + 1):
            return "all"

        # Match by number
        if choice.isdigit():
            idx = int(choice) - 1
            keys = list(DEMOS.keys())
            if 0 <= idx < len(keys):
                return keys[idx]

        # Match by name
        if choice in DEMOS:
            return choice

        print("  Invalid choice. Try again.")


async def run(demo_keys: list, api_key: str, server: str, pcm: bytes, sr: int):
    """Run the selected demos."""
    for key in demo_keys:
        _, func = DEMOS[key]
        await func(api_key, server, pcm, sr)


def main():
    parser = argparse.ArgumentParser(
        description="Speechmatics Voice API Explorer — demo all features",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Available demos:
  rt            RT mode basic transcription (partials, finals, confidence)
  rt-translate  RT mode with real-time translation (Spanish, French)
  voice         Voice mode with adaptive profile (segments, turns, metrics)
  profiles      Compare all voice profiles (agile, adaptive, smart, external)
  advanced      Speaker focus, ForceEOU, GetSpeakers, diarization
  messages      Message control include/exclude
  all           Run all demos in sequence

Audio input:
  Default is live microphone — speak, press Enter to stop.
  Use --audio to provide a WAV file instead.
        """,
    )
    parser.add_argument(
        "demo",
        nargs="?",
        default=None,
        help="Demo to run (see list above). Omit for interactive menu.",
    )
    parser.add_argument(
        "--server",
        default=os.getenv("SPEECHMATICS_SERVER", DEFAULT_SERVER),
        help=f"WebSocket server URL (default: {DEFAULT_SERVER})",
    )
    parser.add_argument(
        "--audio",
        default=None,
        help="Path to a 16-bit mono WAV file. If omitted, records from microphone.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show raw WebSocket URL, StartRecognition payload, and all received messages.",
    )
    args = parser.parse_args()

    global DEBUG
    DEBUG = args.debug

    # ── Validate API key ──
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file or environment")
        sys.exit(1)

    # ── Select demo first (before recording) ──
    if args.demo:
        demo_key = args.demo.lower()
    else:
        demo_key = show_menu()

    if demo_key is None:
        print("Exiting.")
        return

    if demo_key == "all":
        keys = list(DEMOS.keys())
    elif demo_key in DEMOS:
        keys = [demo_key]
    else:
        print(f"Unknown demo: {demo_key}")
        print(f"Available: {', '.join(DEMOS.keys())}, all")
        sys.exit(1)

    # ── Get audio ──
    if args.audio:
        # File mode
        audio_path = Path(args.audio)
        if not audio_path.exists():
            print(f"Error: Audio file not found: {audio_path}")
            sys.exit(1)
        try:
            pcm, sr = read_wav(audio_path)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        # Microphone mode (default)
        print()
        print("=" * 60)
        print("  Microphone Input")
        print("=" * 60)
        print()
        print("  Your recording will be replayed through each demo.")
        print("  Tip: speak a few sentences for best results.")
        print()
        pcm, sr = record_audio()

        if len(pcm) < sr * 2:  # Less than 1 second
            print("  Error: Recording too short. Please try again.")
            sys.exit(1)

    # ── Run ──
    print()
    print(f"  Server: {args.server}")
    asyncio.run(run(keys, api_key, args.server, pcm, sr))

    print()
    print("=" * 60)
    print("  All demos complete.")
    print("=" * 60)


if __name__ == "__main__":
    main()
