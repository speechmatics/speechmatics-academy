#!/usr/bin/env python3
"""
Melia Multilingual Transcription

Transcribe multilingual, code-switching audio with Melia over the Batch API.
Set the model to "melia-1" and the language to "multi", and a recording that
moves between languages comes back as one continuous transcript.
"""

import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

from speechmatics.batch import (
    AsyncClient,
    AuthenticationError,
    FormatType,
    JobConfig,
    JobType,
    TranscriptionConfig,
)

load_dotenv()

# Multilingual transcripts contain characters outside the console's default
# encoding (Windows uses cp1252); force UTF-8 so the output always prints.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


class MeliaJob(JobConfig):
    """Select Melia: model "melia-1", language "multi".

    "melia-1" is the newest model and is not yet a typed field on the SDK's
    TranscriptionConfig, so we set it when the config is serialized.
    """

    def to_dict(self) -> dict:
        config = super().to_dict()
        config["transcription_config"]["model"] = "melia-1"
        config["transcription_config"].pop("operating_point", None)
        return config


async def main() -> None:
    """Transcribe an audio file with Melia."""
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    if len(sys.argv) > 1:
        audio_file = sys.argv[1]
    else:
        audio_file = str(Path(__file__).parent.parent / "assets" / "sample.wav")

    melia = MeliaJob(
        type=JobType.TRANSCRIPTION,
        transcription_config=TranscriptionConfig(language="multi"),
    )

    try:
        async with AsyncClient(api_key=api_key) as client:
            # submit the job and wait for it to finish.
            job = await client.submit_job(audio_file, config=melia)
            transcript = await client.wait_for_completion(job.id, format_type=FormatType.TXT)
            print(transcript)

            # Melia tags every word with its language; list the distinct ones.
            result = await client.get_transcript(job.id, format_type=FormatType.JSON)
            languages = sorted(
                {
                    alt.language
                    for item in result.results
                    if item.type == "word" and item.alternatives
                    for alt in item.alternatives[:1]
                    if alt.language
                }
            )
            if languages:
                print(f"\nLanguages detected: {', '.join(languages)}")
    except AuthenticationError as e:
        print(f"Authentication failed: {e}")


if __name__ == "__main__":
    asyncio.run(main())
