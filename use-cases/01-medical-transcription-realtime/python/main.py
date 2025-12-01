"""
Healthcare & Medical - Real-Time Transcription

Live transcription for clinical notes, patient interviews, and telemedicine.
"""

import asyncio
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncClient,
    AuthenticationError,
    TranscriptionConfig,
    ServerMessageType,
)

load_dotenv()

# Store transcripts
transcripts = []


async def main():
    """Transcribe medical recordings in real-time with custom vocabulary."""
    # Paths
    assets_dir = Path(__file__).parent.parent / "assets"
    audio_file = assets_dir / "sample.wav"
    output_file = assets_dir / "transcript.txt"

    if not audio_file.exists():
        print(f"Error: Audio file '{audio_file}' not found")
        print("Please provide a medical recording as 'sample.wav' in the assets/ folder")
        return

    # Configure transcription with medical vocabulary
    config = TranscriptionConfig(
        language="en",
        enable_partials=True,
        additional_vocab=[
            {"content": "hypertension"},
            {"content": "metformin"},
            {"content": "echocardiogram"},
            {"content": "tachycardia"},
            {"content": "bronchitis"},
            {"content": "acetaminophen"},
            {"content": "electrocardiogram"},
            {"content": "MRI", "sounds_like": ["M R I", "M. R. I."]},
            {"content": "CT scan", "sounds_like": ["C T scan"]},
            {"content": "diabetes mellitus"},
        ],
    )

    print(f"{'='*80}")
    print("MEDICAL TRANSCRIPTION (Real-Time)")
    print(f"{'='*80}")
    print(f"Processing: {audio_file.name}")
    print()

    try:
        async with AsyncClient() as client:
            # Register event handlers
            @client.on(ServerMessageType.ADD_TRANSCRIPT)
            def handle_transcript(msg):
                """Handle final transcripts."""
                text = msg["metadata"]["transcript"]
                if text.strip():
                    transcripts.append(text)
                    print(f"Final: {text}")

            @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
            def handle_partial(msg):
                """Handle partial transcripts (real-time feedback)."""
                text = msg["metadata"]["transcript"]
                if text.strip():
                    print(f"Partial: {text}")

            # Transcribe the audio file
            with open(audio_file, "rb") as f:
                await client.transcribe(f, transcription_config=config)

        # Save transcript to assets folder
        full_transcript = " ".join(transcripts)
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(full_transcript)

        print()
        print(f"{'='*80}")
        print(f"Transcript saved to: {output_file}")
        print(f"{'='*80}")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")
    except Exception as e:
        print(f"\nError: {type(e).__name__}: {e}")


if __name__ == "__main__":
    asyncio.run(main())
