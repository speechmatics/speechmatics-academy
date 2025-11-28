#!/usr/bin/env python3
"""
Text-to-Speech - Your First Speechmatics TTS

Convert text to natural-sounding speech using Speechmatics TTS API.
"""

import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from speechmatics.tts import AsyncClient, Voice, OutputFormat, AuthenticationError

# Load environment variables
load_dotenv()


async def main():
    """Generate speech from text using Speechmatics TTS."""

    # Get API key from environment
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    # Default text
    default_text = "Hello! Welcome to Speechmatics text to speech. This is a demonstration of natural sounding speech synthesis."

    # Output file path
    output_file = Path(__file__).parent.parent / "assets" / "output.wav"

    # Ensure assets directory exists
    output_file.parent.mkdir(parents=True, exist_ok=True)

    print("Speechmatics Text-to-Speech Demo")
    print("=" * 40)
    print()
    print("Available voices:")
    print("  - sarah: English Female (UK)")
    print("  - theo: English Male (UK)")
    print("  - megan: English Female (US)")
    print("  - jack: English Male (US)")
    print()

    # Get user input or use default
    user_input = input(f"Enter text to speak (or press Enter for default): ").strip()
    text = user_input if user_input else default_text

    print()
    print(f"Text: {text}")
    print(f"Voice: Sarah (English UK Female)")
    print(f"Output: {output_file.name}")
    print()

    try:
        # Initialize TTS client
        async with AsyncClient(api_key=api_key) as client:
            print("Generating speech...")

            # Generate speech
            response = await client.generate(
                text=text,
                voice=Voice.SARAH,
                output_format=OutputFormat.WAV_16000,
            )

            # Read audio data and save to file
            audio_data = await response.read()
            with open(output_file, "wb") as f:
                f.write(audio_data)

            print(f"Audio saved to: {output_file}")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
