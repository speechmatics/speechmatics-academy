"""
Call Center Analytics

Transcribe calls with channel diarization (stereo),
plus sentiment analysis, topic detection, and summarization.

"""

import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv

from speechmatics.batch import (
    AsyncClient,
    AuthenticationError,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SummarizationConfig,
    SentimentAnalysisConfig,
    TopicDetectionConfig,
    OperatingPoint,
)

load_dotenv()

# Channel labels for stereo call recordings
CHANNEL_LABELS = ["Agent", "Customer"]


def format_transcript(results):
    """
    Build transcript with channel labels.
    Custom formatting here.
    """
    def join_words(words):
        if not words:
            return ""
        text = words[0]
        for word in words[1:]:
            if word in ".,!?;:'\"":
                text += word
            else:
                text += " " + word
        return text

    lines = []
    current_channel = None
    current_words = []

    for r in results:
        if not r.alternatives:
            continue

        content = r.alternatives[0].content
        channel = r.channel

        if channel != current_channel:
            if current_words and current_channel:
                lines.append(f"{current_channel}: {join_words(current_words)}")
            current_channel = channel
            current_words = []

        if content:
            current_words.append(content)

    if current_words and current_channel:
        lines.append(f"{current_channel}: {join_words(current_words)}")

    return "\n".join(lines)


async def main():
    """Analyze call recordings with full analytics suite."""
    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    if not audio_file.exists():
        print(f"Error: Audio file '{audio_file}' not found")
        print("Place your stereo call recording as 'sample.wav' in assets/")
        return

    try:
        async with AsyncClient(api_key=api_key) as client:
            print(f"Submitting job for: {audio_file}")
            print(f"Channel labels: {CHANNEL_LABELS[0]} (Ch1), {CHANNEL_LABELS[1]} (Ch2)")
            print()

            config = JobConfig(
                type=JobType.TRANSCRIPTION,
                transcription_config=TranscriptionConfig(
                    language="en",
                    operating_point=OperatingPoint.ENHANCED,
                    diarization="channel",
                    channel_diarization_labels=CHANNEL_LABELS,
                ),
                sentiment_analysis_config=SentimentAnalysisConfig(),
                topic_detection_config=TopicDetectionConfig(),
                summarization_config=SummarizationConfig(
                    content_type="conversational", summary_length="brief"
                ),
            )

            job = await client.submit_job(str(audio_file), config=config)
            print(f"Job submitted with ID: {job.id}")
            print("Waiting for completion...")

            result = await client.wait_for_completion(job.id)

            # Transcript
            print("=" * 80)
            print("CALL TRANSCRIPT")
            print("=" * 80)
            print(format_transcript(result.results) + "\n")

            # Sentiment
            if result.sentiment_analysis:
                print("=" * 80)
                print("SENTIMENT ANALYSIS")
                print("=" * 80)
                segments = result.sentiment_analysis.get("segments", [])
                if segments:
                    counts = {"positive": 0, "negative": 0, "neutral": 0}
                    for seg in segments:
                        s = seg.get("sentiment", "").lower()
                        if s in counts:
                            counts[s] += 1
                    overall = max(counts, key=counts.get)
                    print(f"Overall: {overall.capitalize()}")
                    print(f"Breakdown: {counts['positive']} positive, {counts['neutral']} neutral, {counts['negative']} negative\n")

            # Topics
            if result.topics and "summary" in result.topics:
                print("=" * 80)
                print("TOPICS DISCUSSED")
                print("=" * 80)
                overall = result.topics["summary"]["overall"]
                topics = [t for t, c in overall.items() if c > 0]
                print(f"Topics: {', '.join(topics)}\n")

            # Summary
            if result.summary:
                print("=" * 80)
                print("CALL SUMMARY")
                print("=" * 80)
                print(f"{result.summary.get('content', 'N/A')}\n")

    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")


if __name__ == "__main__":
    asyncio.run(main())
