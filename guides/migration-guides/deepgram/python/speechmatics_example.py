"""
Speechmatics Real-time Streaming Example
Shows how to stream audio to Speechmatics for real-time transcription
(Equivalent to the Deepgram example)
"""

import asyncio
import os
from pathlib import Path
from speechmatics.rt import AsyncClient, ServerMessageType, TranscriptResult, AudioFormat, TranscriptionConfig
from dotenv import load_dotenv

load_dotenv()

async def main():
    """Stream audio to Speechmatics for real-time transcription"""

    # Initialize the Speechmatics client
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        raise ValueError("SPEECHMATICS_API_KEY environment variable not set")

    # Path to your audio file
    audio_file_path = Path(__file__).parent.parent / "assets" / "sample.wav"

    async with AsyncClient(api_key=api_key) as client:

        # Define event handlers using decorators
        @client.on(ServerMessageType.RECOGNITION_STARTED)
        def on_session_started(message):
            print("Connection opened to Speechmatics")

        @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def on_partial_transcript(message):
            result = TranscriptResult.from_message(message)
            if result.metadata.transcript:
                print(f"[INTERIM] {result.metadata.transcript}", end="\r")

        @client.on(ServerMessageType.ADD_TRANSCRIPT)
        def on_final_transcript(message):
            result = TranscriptResult.from_message(message)
            if result.metadata.transcript:
                print(f"[FINAL] {result.metadata.transcript}")

        @client.on(ServerMessageType.ERROR)
        def on_error(message):
            print(f"Error: {message}")

        @client.on(ServerMessageType.END_OF_TRANSCRIPT)
        def on_end_of_transcript(message):
            print("\nTranscription complete")

        # Configure transcription options
        config = TranscriptionConfig(
            language="en",
            operating_point="enhanced",  # Equivalent to nova-2
            diarization="speaker",
            enable_entities=True,  # Equivalent to smart_format
            enable_partials=True  # Enable interim results
        )

        # Configure audio format (use defaults to auto-detect WAV file format)
        audio_format = AudioFormat()

        # Transcribe audio (automatically handles session and streaming)
        print("Starting Speechmatics streaming...")
        try:
            with open(audio_file_path, "rb") as audio_file:
                await client.transcribe(
                    audio_file,
                    transcription_config=config,
                    audio_format=audio_format
                )

        except FileNotFoundError:
            print(f"Error: Audio file '{audio_file_path}' not found")
        except Exception as e:
            print(f"Error during streaming: {e}")

if __name__ == "__main__":
    asyncio.run(main())
