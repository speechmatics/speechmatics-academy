"""
Channel Diarization - Transcribe multi-channel audio with speaker attribution.

Each audio file = one channel (e.g., Agent on channel 1, Customer on channel 2).
"""

import asyncio
import io
import os
import sys
import wave
from pathlib import Path

from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncMultiChannelClient,
    AudioEncoding,
    AudioFormat,
    ServerMessageType,
    TranscriptionConfig,
    TranscriptResult,
)

load_dotenv()

ASSETS_DIR = Path(__file__).parent.parent / "assets"
LABELS = ["Customer", "Agent"]


def get_pcm(path: Path) -> bytes:
    """Extract raw PCM from WAV file."""
    with wave.open(str(path), "rb") as wav:
        return wav.readframes(wav.getnframes())


async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: Set SPEECHMATICS_API_KEY in .env")
        return

    agent_file = ASSETS_DIR / "Agent.wav"
    customer_file = ASSETS_DIR / "Customer.wav"

    if not agent_file.exists() or not customer_file.exists():
        print(f"Error: Place Agent.wav and Customer.wav in {ASSETS_DIR}")
        return

    results = {label: [] for label in LABELS}
    done = asyncio.Event()

    async with AsyncMultiChannelClient(api_key=api_key) as client:

        @client.on(ServerMessageType.ADD_TRANSCRIPT)
        def on_transcript(msg):
            result = TranscriptResult.from_message(msg)
            text = result.metadata.transcript.strip()
            if not text:
                return
            channel = msg.get("channel", "Unknown")
            start = result.metadata.start_time
            print(f"[{int(start//60):02d}:{int(start%60):02d}] {channel}: {text}")
            if channel in results:
                results[channel].append(text)

        @client.on(ServerMessageType.END_OF_TRANSCRIPT)
        def on_end(msg):
            print("\n" + "=" * 50)
            print("SUMMARY")
            print("=" * 50)
            for channel, segments in results.items():
                print(f"\n{channel}: {' '.join(segments)}")
            done.set()

        @client.on(ServerMessageType.ERROR)
        def on_error(msg):
            print(f"[ERROR] {msg.get('reason')}")

        sources = {
            "channel1": io.BytesIO(get_pcm(customer_file)),
            "channel2": io.BytesIO(get_pcm(agent_file)),
        }

        config = TranscriptionConfig(
            language="en",
            diarization="channel",
            channel_diarization_labels=LABELS,
        )

        audio_format = AudioFormat(
            encoding=AudioEncoding.PCM_S16LE,
            sample_rate=16000,
        )

        print("Transcribing...\n")
        await client.transcribe(
            sources=sources,
            transcription_config=config,
            audio_format=audio_format,
        )

        await done.wait()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
