#!/usr/bin/env python3
"""
Audio Intelligence - Sentiment, Topics & Summaries

Extract insights from audio using Speechmatics Audio Intelligence features.
"""

import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SentimentAnalysisConfig,
    SummarizationConfig,
    TopicDetectionConfig,
    AuthenticationError,
)

load_dotenv()


async def main():
    """Demonstrate audio intelligence features."""

    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    print("=" * 70)
    print("AUDIO INTELLIGENCE - Sentiment + Summaries")
    print("=" * 70)
    print()

    try:
        async with AsyncClient(api_key=api_key) as client:
            # Configure with audio intelligence features
            config = JobConfig(
                type=JobType.TRANSCRIPTION,
                transcription_config=TranscriptionConfig(
                    language="en",
                    enable_entities=True,
                ),
                sentiment_analysis_config=SentimentAnalysisConfig(),
                topic_detection_config=TopicDetectionConfig(),
                summarization_config=SummarizationConfig(
                    content_type="conversational",
                    summary_length="detailed",
                    summary_type="bullets",
                ),
            )

            print("Transcribing with audio intelligence...")
            print("   - Sentiment analysis")
            print("   - Topic Detection")
            print("   - Summarization")
            print()

            # Submit job
            job = await client.submit_job(str(audio_file), config=config)
            print(f"Job ID: {job.id}")
            print("Processing...")
            print()

            # Wait for completion
            result = await client.wait_for_completion(job.id, timeout=300.0)

            # Display results
            print("=" * 70)
            print("RESULTS")
            print("=" * 70)
            print()

            print("Transcript:")
            print("-" * 70)
            print(result.transcript_text)
            print("-" * 70)
            print()

            # Display sentiment if available
            if result.sentiment_analysis:
                segments = result.sentiment_analysis.get('segments', [])
                if segments:
                    # Calculate overall sentiment from segments
                    sentiment_counts = {'positive': 0, 'negative': 0, 'neutral': 0}
                    for segment in segments:
                        sentiment = segment.get('sentiment', '').lower()
                        if sentiment in sentiment_counts:
                            sentiment_counts[sentiment] += 1

                    overall = max(sentiment_counts, key=sentiment_counts.get)
                    print(f"Sentiment: {overall}")
                    print()

            # Display topics if available
            if result.topics:
                overall_topics = result.topics.get('summary', {}).get('overall', {})
                detected = [topic for topic, count in overall_topics.items() if count > 0]
                if detected:
                    print("Topics:")
                    for topic in detected:
                        print(f"   • {topic}")
                    print()

            # Display summary if available
            if result.summary:
                content = result.summary.get('content', '')
                if content:
                    print("Summary:")
                    # Handle multi-line summaries (bullets or structured text)
                    if '\n' in content:
                        for line in content.split('\n'):
                            if line.strip():
                                print(f"   {line}")
                    else:
                        # Single paragraph
                        print(f"   {content}")
                    print()

            print("Audio intelligence analysis complete!")

    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")


if __name__ == "__main__":
    asyncio.run(main())
