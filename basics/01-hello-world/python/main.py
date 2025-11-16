#!/usr/bin/env python3
"""
Hello World - Your First Speechmatics Transcription

"""

import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, AuthenticationError

# Load environment variables
load_dotenv()


async def main():
    """Transcribe an audio file """

    # Get API key from environment
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    # Path to sample audio file
    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    print("Transcribing audio file...")
    print(f"File: {audio_file.name}")
    print()

    try:
        # Initialize client and transcribe
        async with AsyncClient(api_key=api_key) as client:
            # Transcribe - this is the simplest way!
            result = await client.transcribe(str(audio_file))
            # Print the transcript
            print(result.transcript_text)
       
    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
