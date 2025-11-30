"""
Configuration Guide 
Demonstrates configuration options.
Perfect reference for seeing what's possible!
"""

import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig, OperatingPoint, AuthenticationError

load_dotenv()


async def main():
    """Demonstrate all major configuration options."""

    api_key = os.getenv("SPEECHMATICS_API_KEY")

    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    print("=" * 70)
    print("SPEECHMATICS CONFIGURATION GUIDE")
    print("=" * 70)
    print()

    try:
        # Comprehensive configuration
        config = TranscriptionConfig(
            # Language settings
            language="en",

            # Speaker diarization
            diarization="speaker",

            # Custom vocabulary for better accuracy
            # Shows both simple terms and phonetic alternatives
            additional_vocab=[
                {"content": "Speechmatics", "sounds_like": ["speech matics", "speech mattics"]},
                {"content": "transcription"},
                {"content": "API", "sounds_like": ["A P I", "ay pee eye"]},
                {"content": "demo"},
            ],

            # Formatting options
            enable_entities=True,  # Detect dates, times, numbers, currencies

            # Quality settings
            operating_point="enhanced",  # Best accuracy or "standard" best for speed
        )

        print(" Configuration:")
        print(f"   Language: {config.language}")
        print(f"   Diarization: {config.diarization}")
        print(f"   Custom vocabulary: {len(config.additional_vocab)} terms")
        print(f"   Entity detection: {config.enable_entities}")
        print(f"   Operating point: {config.operating_point}")
        print()

        print(" Transcribing with full configuration...")
        print()

        # Transcribe with configuration
        async with AsyncClient(api_key=api_key) as client:
            result = await client.transcribe(str(audio_file), transcription_config=config)

        # Display results
        print("=" * 70)
        print("RESULTS")
        print("=" * 70)
        print()

        print("Transcript:")
        print(result.transcript_text)
        print()

        # Display detected entities if available
        # Note: The SDK doesn't currently expose entity_class, so we show content only
        if result.results:
            entities = [r for r in result.results if r.type == "entity"]
            if entities:
                print("Detected Entities:")
                print("-" * 70)
                for entity in entities:
                    if entity.alternatives:
                        content = entity.alternatives[0].content
                        # Format time range if available
                        time_info = ""
                        if entity.start_time is not None:
                            time_info = f" @ {entity.start_time:.2f}s"
                        print(f"   • {content}{time_info}")
                print()
                print("(Entity types: date, time, money, percentage, cardinal)")
                print()
            else:
                print("No entities detected in this audio.")
                print("(Entities include: dates, times, numbers, currencies, etc.)")
                print()

        print(" Configuration demo complete!")
        print()
        print(" This example showed:")
        print("   Speaker diarization")
        print("   Custom vocabulary with phonetic alternatives (sounds_like)")
        print("   Entity detection (dates, times, numbers, etc.)")
        print("   Enhanced accuracy mode")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
