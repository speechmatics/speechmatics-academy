#!/usr/bin/env python3
"""Real-time transcription with microphone."""

import asyncio
import os
from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncClient,
    ServerMessageType,
    TranscriptionConfig,
    TranscriptResult,
    OperatingPoint,
    AudioFormat,
    AudioEncoding,
    Microphone,
    AuthenticationError,
)

load_dotenv()


async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    transcript_parts = []

    audio_format = AudioFormat(
        encoding=AudioEncoding.PCM_S16LE,
        chunk_size=4096,
        sample_rate=16000,
    )

    transcription_config = TranscriptionConfig(
        language="en",
        enable_partials=True,
        operating_point=OperatingPoint.ENHANCED,
    )

    mic = Microphone(
        sample_rate=audio_format.sample_rate,
        chunk_size=audio_format.chunk_size,
    )

    if not mic.start():
        print("PyAudio not installed. Install: pip install pyaudio")
        return

    try:
        async with AsyncClient(api_key=api_key) as client:
            @client.on(ServerMessageType.ADD_TRANSCRIPT)
            def handle_final_transcript(message):
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    print(f"[final]: {transcript}")
                    transcript_parts.append(transcript)

            @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
            def handle_partial_transcript(message):
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    print(f"[partial]: {transcript}")

            try:
                print("Connected! Start speaking (Ctrl+C to stop)...\n")

                await client.start_session(
                    transcription_config=transcription_config,
                    audio_format=audio_format,
                )

                while True:
                    frame = await mic.read(audio_format.chunk_size)
                    await client.send_audio(frame)

            except KeyboardInterrupt:
                pass
            finally:
                mic.stop()
                print(f"\n\nFull transcript: {' '.join(transcript_parts)}")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
