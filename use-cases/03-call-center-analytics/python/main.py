"""
Call Center Analytics Test Script

Transcribe calls with speaker diarization, sentiment analysis, and topic detection.
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
)

# Load environment variables from .env file
load_dotenv()


async def main():
    """
    Analyze call recordings with full analytics suite.
    """
    # Get API key from environment
    SPEECHMATICS_API_KEY = os.getenv("SPEECHMATICS_API_KEY")

    # Audio file path - update this with your actual call recording
    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    if not os.path.exists(audio_file):
        print(f"Error: Audio file '{audio_file}' not found")
        print("Please provide a call recording file in this directory")
        return

    try:
        async with AsyncClient(api_key=SPEECHMATICS_API_KEY) as client:
            print(f"Submitting job for: {audio_file}")

            # Configure call analytics with all features
            config = JobConfig(
                type=JobType.TRANSCRIPTION,
                transcription_config=TranscriptionConfig(
                    language="en",
                    diarization="speaker",
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

            # Full transcript with speaker labels
            print("\n" + "="*80)
            print("CALL TRANSCRIPT")
            print("="*80)
            print(f"{result.transcript_text}\n")

            # Sentiment analysis
            if result.sentiment_analysis:
                print("="*80)
                print("SENTIMENT ANALYSIS")
                print("="*80)
                segments = result.sentiment_analysis.get('segments', [])
                if segments:
                    sentiment_counts = {'positive': 0, 'negative': 0, 'neutral': 0}
                    for segment in segments:
                        sentiment = segment.get('sentiment', '').lower()
                        if sentiment in sentiment_counts:
                            sentiment_counts[sentiment] += 1
                    overall = max(sentiment_counts, key=sentiment_counts.get)
                    print(f"Overall: {overall.capitalize()}")
                    print(f"Breakdown: {sentiment_counts['positive']} positive, {sentiment_counts['neutral']} neutral, {sentiment_counts['negative']} negative\n")

            # Topics discussed
            if result.topics and 'summary' in result.topics:
                print("="*80)
                print("TOPICS DISCUSSED")
                print("="*80)
                overall = result.topics['summary']['overall']
                detected_topics = [topic for topic, count in overall.items() if count > 0]
                print(f"Topics: {', '.join(detected_topics)}\n")

            # Call summary
            if result.summary:
                print("="*80)
                print("CALL SUMMARY")
                print("="*80)
                print(f"{result.summary.get('content', 'N/A')}\n")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
