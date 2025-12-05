#!/usr/bin/env python3
"""
Multilingual & Translation

Demonstrate real-time transcription and translation using microphone input.
"""

import asyncio
import os
from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncClient,
    AudioEncoding,
    AudioFormat,
    Microphone,
    TranscriptionConfig,
    TranslationConfig,
    TranscriptResult,
    ServerMessageType,
    AuthenticationError,
)

load_dotenv()


async def main() -> None:
    """Demonstrate real-time transcription and translation with microphone input."""

    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    transcript_parts = []
    translations = {"es": [], "ru": []}

    # Configure audio format and transcription
    audio_format = AudioFormat(
        encoding=AudioEncoding.PCM_S16LE,
        chunk_size=4096,
        sample_rate=16000,
    )

    transcription_config = TranscriptionConfig(
        language="en",
        enable_partials=True,
    )

    translation_config = TranslationConfig(
        target_languages=["es", "ru"],
        enable_partials=True,
    )

    mic = Microphone(
        sample_rate=audio_format.sample_rate,
        chunk_size=audio_format.chunk_size,
    )

    if not mic.start():
        print("PyAudio not installed - microphone not available")
        print("Install with: pip install pyaudio")
        return

    async with AsyncClient(api_key=api_key) as client:
        # Register callbacks for transcript events
        @client.on(ServerMessageType.ADD_TRANSCRIPT)
        def handle_final_transcript(message):
            result = TranscriptResult.from_message(message)
            transcript = result.metadata.transcript
            if transcript:
                print(f"[EN]: {transcript}")
                transcript_parts.append(transcript.strip())

        @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def handle_partial_transcript(message):
            result = TranscriptResult.from_message(message)
            transcript = result.metadata.transcript
            if transcript:
                print(f"[EN partial]: {transcript}")

        # Register callbacks for translation events
        @client.on(ServerMessageType.ADD_TRANSLATION)
        def handle_final_translation(message):
            language = message.get("language")
            if "results" in message and message["results"]:
                translation = " ".join([r["content"] for r in message["results"]])
                if translation:
                    lang_name = "ES" if language == "es" else "RU"
                    print(f"[{lang_name}]: {translation}")
                    translations[language].append(translation.strip())

        @client.on(ServerMessageType.ADD_PARTIAL_TRANSLATION)
        def handle_partial_translation(message):
            language = message.get("language")
            if "results" in message and message["results"]:
                translation = " ".join([r["content"] for r in message["results"]]).strip()
                if translation:
                    lang_name = "ES" if language == "es" else "RU"
                    print(f"[{lang_name} partial]: {translation}")

        try:
            print("Microphone started - speak now...")
            print("Press Ctrl+C to stop transcription\n")

            await client.start_session(
                transcription_config=transcription_config,
                translation_config=translation_config,
                audio_format=audio_format,
            )

            while True:
                frame = await mic.read(audio_format.chunk_size)
                await client.send_audio(frame)

        except AuthenticationError as e:
            print(f"\nAuthentication failed: {e}")
        except asyncio.CancelledError:
            print("\nTranscription session cancelled")
            print(f"\nFull transcript: {' '.join(transcript_parts)}")
            if translations["es"]:
                print(f"Spanish: {' '.join(translations['es'])}")
            if translations["ru"]:
                print(f"Russian: {' '.join(translations['ru'])}")
        except Exception as e:
            print(f"\nTranscription error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
