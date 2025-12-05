import asyncio
import os
import time
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig, OperatingPoint, AuthenticationError

load_dotenv()


async def main():
    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    # Display file information
    file_size_bytes = audio_file.stat().st_size
    file_size_mb = file_size_bytes / (1024 * 1024)

    print(f"Processing file: {audio_file.name}")
    print(f"File size: {file_size_mb:.1f} MB")
    print()
    print("[... processing ...]")
    print()

    try:
        # Track processing time
        start_time = time.time()

        # Initialize batch client
        async with AsyncClient(api_key=api_key) as client:
            # Configure transcription
            config = TranscriptionConfig(
                language="en",
                operating_point=OperatingPoint.ENHANCED,
            )

            # Transcribe with batch API
            result = await client.transcribe(
                str(audio_file),
                transcription_config=config,
            )

        # Calculate actual processing time
        end_time = time.time()
        processing_time = end_time - start_time
        minutes = int(processing_time // 60)
        seconds = int(processing_time % 60)

        print(f"Complete! Processing time: {minutes}m {seconds}s")
        print()

        # Extract and display transcript
        transcript = result.transcript_text
        print("Full transcript:")
        print(f'"{transcript}"')

    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")

if __name__ == "__main__":
    asyncio.run(main())