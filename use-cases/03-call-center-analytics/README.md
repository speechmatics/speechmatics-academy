# Call Center Analytics - Analyze Call Recordings

**Extract insights from call recordings with transcription, sentiment analysis, topic detection, and summarization.**

Ideal for quality assurance, compliance monitoring, and customer experience improvement.

## What You'll Learn

- Transcribing call recordings with speaker diarization
- Analyzing sentiment across conversation segments
- Detecting topics discussed in calls
- Generating automated call summaries
- Processing batch audio with the Batch API

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Audio file**: Call recording in WAV, MP3, or other supported format

## Quick Start

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv venv
venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv venv
source venv/bin/activate
```

**Step 2: Install dependencies and run**

```bash
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
python main.py
```

Place your call recording as `sample.wav` in the `assets/` folder before running.

## How It Works

> [!NOTE]
> This example uses the Batch API to process recorded calls with full audio intelligence:
>
> 1. **Submit job** - Upload audio with analytics configuration
> 2. **Process** - Speechmatics transcribes and analyzes
> 3. **Results** - Get transcript, sentiment, topics, and summary

### Configuration

```python
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SentimentAnalysisConfig,
    TopicDetectionConfig,
    SummarizationConfig,
)

config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(
        language="en",
        diarization="speaker",  # Identify different speakers
    ),
    sentiment_analysis_config=SentimentAnalysisConfig(),
    topic_detection_config=TopicDetectionConfig(),
    summarization_config=SummarizationConfig(
        content_type="conversational",
        summary_length="brief",
    ),
)

async with AsyncClient(api_key=api_key) as client:
    job = await client.submit_job(audio_file, config=config)
    result = await client.wait_for_completion(job.id)
```

### Configuration Options

| Parameter | Options | Description |
|-----------|---------|-------------|
| `language` | `"en"`, `"es"`, `"fr"`, etc. | Transcription language |
| `diarization` | `"speaker"`, `"none"` | Speaker identification |
| `summary_length` | `"brief"`, `"detailed"` | Summary detail level |
| `content_type` | `"conversational"`, `"general"` | Content optimization |

## Expected Output

```
Submitting job for: .../assets/sample.wav
Job submitted with ID: s756f7ihqk
Waiting for completion...

================================================================================
CALL TRANSCRIPT
================================================================================
SPEAKER S1: Thank you for calling customer support. How can I help you today?
SPEAKER S2: Hi. I'm having trouble with my recent order.
SPEAKER S1: I'd be happy to help you with that. Can you provide your order number?

================================================================================
SENTIMENT ANALYSIS
================================================================================
Overall: Neutral
Breakdown: 2 positive, 3 neutral, 1 negative

================================================================================
TOPICS DISCUSSED
================================================================================
Topics: Business & Finance

================================================================================
CALL SUMMARY
================================================================================
- Customer reports issue with recent order
- Support requests order number for assistance
```

## Key Features Demonstrated

**Audio Intelligence:**
- Speaker diarization (agent vs customer)
- Segment-level sentiment analysis
- Automatic topic detection
- Conversational summarization

**Batch Processing:**
- Async job submission
- Progress monitoring
- Result retrieval

**Use Cases:**
- Quality assurance monitoring
- Compliance review
- Customer satisfaction analysis
- Agent performance metrics

## Supported Audio Formats

- WAV (recommended)
- MP3
- FLAC
- OGG
- M4A
- AAC

## Troubleshooting

**"Audio file not found"**
- Ensure `sample.wav` exists in the `assets/` folder
- Or update `audio_file` path in `main.py`

**"Authentication failed"**
- Check your API key in the `.env` file
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)

**"Unsupported audio format"**
- Convert to WAV, MP3, FLAC, OGG, M4A, or AAC

**Path issues on Windows**
- Use forward slashes `/` or raw strings `r"C:\path\to\file.wav"`

## Resources

- [Batch API Documentation](https://docs.speechmatics.com/introduction/batch-guide)
- [Audio Intelligence Features](https://docs.speechmatics.com/features)
- [Supported Languages](https://docs.speechmatics.com/introduction/supported-languages)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Beginner
**API Mode**: Batch

[Back to Use Cases](../) | [Back to Academy](../../README.md)
