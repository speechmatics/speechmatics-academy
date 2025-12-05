"""
Media & Entertainment - Generate Captions

Add captions, create searchable archives, and generate clips from keywords.
"""

import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, AuthenticationError, TranscriptionConfig, FormatType

load_dotenv()


async def main():
    """Generate SRT captions for video content."""
    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    # Paths
    assets_dir = Path(__file__).parent.parent / "assets"
    video_file = assets_dir / "sample.mp4"
    output_file = assets_dir / "sample.srt"

    if not video_file.exists():
        print(f"Error: Video file '{video_file}' not found")
        print("Please provide a video file as 'sample.mp4' in the assets/ folder")
        return

    try:
        async with AsyncClient(api_key=api_key) as client:
            print(f"Submitting job for: {video_file}")

            job = await client.submit_job(
                str(video_file),
                transcription_config=TranscriptionConfig(language="en")
            )

            print(f"Job submitted with ID: {job.id}")
            print("Waiting for completion...")

            # Get SRT format captions
            captions = await client.wait_for_completion(job.id, format_type=FormatType.SRT)

            # Write captions to assets folder
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(captions)

            print(f"\n{'='*80}")
            print(f"SUCCESS: Captions saved to {output_file}")
            print('='*80)
            print("\nPreview of captions:")
            print('-'*80)
            # Show first 500 characters of captions
            print(captions[:500])
            if len(captions) > 500:
                print("...")

    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")


if __name__ == "__main__":
    asyncio.run(main())
