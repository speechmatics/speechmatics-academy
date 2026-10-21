# Call Center Analytics - Analyze Call Recordings

**Extract insights from call recordings with transcription, sentiment analysis, topic detection, and summarization.**

Ideal for quality assurance, compliance monitoring, and customer experience improvement.

## What You'll Learn

- Channel diarization for stereo recordings (Agent/Customer on separate channels)
- Analyzing sentiment across conversation segments
- Detecting topics discussed in calls
- Generating automated call summaries
- Processing batch audio with the Batch API

## Prerequisites

- **Speechmatics API key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.12+**
- **Stereo audio file**: Call recording with Agent on Channel 1 (left) and Customer on Channel 2 (right)

## Quick Start

Start in `use-cases/03-call-center-analytics/` after cloning the Academy. Commands below are relative to this directory.

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies and run**

```bash
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
python main.py
```

Place your stereo call recording as `sample.wav` in the `assets/` folder before running.

## How It Works

> [!NOTE]
> This example uses the Batch API to process recorded calls with transcription and speech intelligence:
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
    OperatingPoint,
)

# Channel labels for stereo call recordings
CHANNEL_LABELS = ["Agent", "Customer"]

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
        content_type="conversational",
        summary_length="brief",
    ),
)

async with AsyncClient(api_key=api_key) as client:
    job = await client.submit_job(audio_file, config=config)
    result = await client.wait_for_completion(job.id)
```

> [!TIP]
> **Stereo call recordings**: Call center phone systems typically record Agent on one channel and Customer on the other. This example uses `diarization="channel"` to label each channel. This script expects stereo channel diarization. To adapt it for mono recordings, use `diarization="speaker"`, remove `channel_diarization_labels`, and update `format_transcript()` to read `alternative.speaker`; changing the configuration alone currently produces no displayed transcript.

> [!NOTE]
> **Channel diarization response format**: With channel diarization, the speaker label appears in `result.channel` (at the result level), not in `alternative.speaker`. The example code handles this by iterating through results and grouping by channel label.

### Configuration Options

| Parameter | Options | Description |
|-----------|---------|-------------|
| `language` | `"en"`, `"es"`, `"fr"`, etc. | Transcription language |
| `operating_point` | `OperatingPoint.ENHANCED`, `STANDARD` | Enhanced for best accuracy |
| `diarization` | `"channel"`, `"speaker"`, `"none"` | Channel for stereo, speaker for mono |
| `channel_diarization_labels` | `["Agent", "Customer"]` | Custom labels for each channel |
| `summary_length` | `"brief"`, `"detailed"` | Summary detail level |
| `content_type` | `"conversational"`, `"informative"`, `"auto"` | Content optimization |

## Expected Output

```
Submitting job for: .../assets/sample.wav
Channel labels: Agent (Ch1), Customer (Ch2)

Job submitted with ID: ouvse7v92l
Waiting for completion...
================================================================================
CALL TRANSCRIPT
================================================================================
Agent: Thank you for calling support. I'd be happy to help you with that.
Customer: Hi. I need help with my account. Great. My account number is 12345.

================================================================================
SENTIMENT ANALYSIS
================================================================================
Overall: Positive
Breakdown: 3 positive, 2 neutral, 0 negative

================================================================================
TOPICS DISCUSSED
================================================================================
Topics: Business & Finance

================================================================================
CALL SUMMARY
================================================================================
- Caller requests account assistance
- Account number 12345 provided to support
```

## Key Features Demonstrated

**Speech intelligence:**
- Channel diarization for stereo recordings (Agent/Customer labels)
- Segment-level sentiment analysis
- Automatic topic detection
- Conversational summarization

**Batch Processing:**
- Async job submission
- Job completion polling
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

- [Batch API Documentation](https://docs.speechmatics.com/speech-to-text/batch/quickstart)
- [Channel Diarization](https://docs.speechmatics.com/speech-to-text/features/diarization)
- [Audio Intelligence Features](https://docs.speechmatics.com/speech-to-text)
- [Supported Languages](https://docs.speechmatics.com/speech-to-text/languages)

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
