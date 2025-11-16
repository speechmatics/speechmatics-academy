# Audio Intelligence - Sentiment, Topics & Summaries

**Extract insights from audio: sentiment analysis, topic detection, and automatic summaries - all in one API call.**

Go beyond transcription to understand WHAT was said and HOW it was said!

## 🎯 What You'll Learn

- How to enable sentiment analysis (positive/negative/neutral)
- Topic detection for content categorization
- Automatic summarization of conversations
- Combining intelligence features with transcription

## 📋 Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- Completed [Configuration Guide](../03-configuration-guide/)

## 🚀 Quick Start

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
python main.py
```

## 🧠 Audio Intelligence Features

### 1. Sentiment Analysis

Detect the emotional tone of speech segments:

```python
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SentimentAnalysisConfig,
)

config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    sentiment_analysis_config=SentimentAnalysisConfig(),
)
```

**Output**:
```json
{
  "text": "I'm really happy with this service!",
  "sentiment": "positive",
  "confidence": 0.95
}
```

**Use cases**:
- Customer satisfaction analysis
- Call center quality monitoring
- Social media monitoring
- Market research

### 2. Topic Detection

Automatically categorize content by topics:

```python
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    TopicDetectionConfig,
)

config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    topic_detection_config=TopicDetectionConfig(),  # Default categories
)

# Or with custom topics:
config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    topic_detection_config=TopicDetectionConfig(
        topics=["pricing", "deployment", "languages"]
    ),
)
```

**Output**:
```json
{
  "topics": ["Business & Finance", "Education"]
}
```

**Use cases**:
- Content categorization
- Meeting summarization
- Research analysis
- News monitoring

### 3. Summarization

Generate concise summaries of long conversations:

```python
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SummarizationConfig,
)

config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    summarization_config=SummarizationConfig(
        content_type="conversational",  # or "informative", "auto"
        summary_length="brief",          # or "detailed"
        summary_type="paragraphs",       # or "bullets"
    ),
)
```

**Configuration Options:**

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `content_type` | `"auto"`, `"informative"`, `"conversational"` | `"auto"` | **auto** - Automatically selects based on transcript analysis<br>**conversational** - Best for dialogues (calls, meetings, discussions)<br>**informative** - Best for structured content (videos, podcasts, lectures, presentations) |
| `summary_length` | `"brief"`, `"detailed"` | `"brief"` | **brief** - Succinct summary in a few sentences<br>**detailed** - Longer, structured summary with sections |
| `summary_type` | `"paragraphs"`, `"bullets"` | `"paragraphs"` | **paragraphs** - Summary as continuous text<br>**bullets** - Summary as bullet points |

**Examples:**

```python
# Brief conversational summary (calls, meetings)
SummarizationConfig(
    content_type="conversational",
    summary_length="brief",
    summary_type="paragraphs"
)

# Detailed informative summary with bullets (lectures, presentations)
SummarizationConfig(
    content_type="informative",
    summary_length="detailed",
    summary_type="bullets"
)

# Auto-detect with detailed summary
SummarizationConfig(
    content_type="auto",
    summary_length="detailed"
)
```

**Output Example (brief, paragraphs)**:
```
Customer called to inquire about product features.
Representative explained key capabilities and pricing.
Customer expressed satisfaction and requested follow-up documentation.
```

**Output Example (detailed, bullets)**:
```
• Customer inquired about account permissions issue
• Representative identified role change as root cause
• Solution provided: restore admin role
• Additional topics discussed:
  - New reporting feature demo offered
  - 15-minute onboarding call scheduled
  - Tutorial link to be sent via email
```

**Use cases**:
- Meeting notes
- Call summaries
- Content briefs
- Executive summaries

## 💡 Complete Example

Combine all intelligence features:

```python
import asyncio
from speechmatics.batch import (
    AsyncClient,
    JobConfig,
    JobType,
    TranscriptionConfig,
    SentimentAnalysisConfig,
    TopicDetectionConfig,
    SummarizationConfig,
)

async def analyze_audio():
    api_key = "your_api_key"
    audio_file = "call.wav"

    async with AsyncClient(api_key=api_key) as client:
        # Enable all intelligence features
        config = JobConfig(
            type=JobType.TRANSCRIPTION,
            transcription_config=TranscriptionConfig(
                language="en",
                diarization="speaker",  # Also identify speakers
            ),
            sentiment_analysis_config=SentimentAnalysisConfig(),
            topic_detection_config=TopicDetectionConfig(),
            summarization_config=SummarizationConfig(
                content_type="conversational",
                summary_length="brief",
            ),
        )

        # Submit and wait for results
        job = await client.submit_job(audio_file, config=config)
        result = await client.wait_for_completion(job.id)

        # Access intelligence data
        print(f"Transcript: {result.transcript_text}")

        if result.sentiment_analysis:
            print(f"Sentiment: {result.sentiment_analysis}")

        if result.topics:
            print(f"Topics: {result.topics}")

        if result.summary:
            print(f"Summary: {result.summary.get('content')}")

asyncio.run(analyze_audio())
```

## 📊 Transcript Response Fields - Complete Reference

### Core Fields (Always Present)

| Field | Type | Description |
|-------|------|-------------|
| `transcript_text` | `str` | Full transcript as plain text |
| `format` | `str` | JSON format version |
| `job` | `JobInfo` | Job metadata and information |
| `metadata` | `RecognitionMetadata` | Recognition process metadata |
| `results` | `list[RecognitionResult]` | Detailed results with timing |

### Optional Intelligence Fields

| Field | Type | Enabled By | Description |
|-------|------|------------|-------------|
| `sentiment_analysis` | `dict` | `SentimentAnalysisConfig()` | Sentiment per segment + summary |
| `topics` | `dict` | `TopicDetectionConfig()` | Topic categorization + counts |
| `summary` | `dict` | `SummarizationConfig()` | Auto-generated summary |
| `chapters` | `list[dict]` | `AutoChaptersConfig()` | Auto-generated chapter markers |
| `translations` | `dict` | `TranslationConfig()` | Translations by language code |
| `audio_events` | `list[dict]` | `AudioEventsConfig()` | Music, laughter, etc. with timestamps |
| `audio_event_summary` | `dict` | `AudioEventsConfig()` | Summary of audio events |

### Field Structures

#### `sentiment_analysis`
```python
{
  "segments": [
    {
      "text": "I'm really happy with this service!",
      "sentiment": "positive",
      "confidence": 0.95,
      "start_time": 10.5,
      "end_time": 12.3
    }
  ],
  "summary": { ... }  # Summary stats if available
}
```

**Access pattern:**
```python
if result.sentiment_analysis:
    segments = result.sentiment_analysis.get('segments', [])
    for segment in segments:
        sentiment = segment.get('sentiment')  # 'positive', 'negative', 'neutral'
```

#### `topics`

**Two modes of topic detection:**

**Mode 1: Auto-detect (Default 10 Categories)**
```python
# Detect from standard categories
config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    topic_detection_config=TopicDetectionConfig(),  # No topics specified
)
```

**Mode 2: Custom Topic List**
```python
# Detect specific custom topics
config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="en"),
    topic_detection_config=TopicDetectionConfig(
        topics=["pricing", "deployment", "languages"]  # Custom topics
    ),
)
```

**Response structure:**
```python
{
  "segments": [
    {
      "text": "...",
      "topics": [{"topic": "Business & Finance"}],
      "start_time": 20.76,
      "end_time": 27.88
    }
  ],
  "summary": {
    "overall": {
      # When using default detection: All 10 categories with counts
      "Business & Finance": 2,
      "Education": 1,
      "Entertainment": 0,
      "Events & Attractions": 0,
      "Food & Drink": 0,
      "News & Politics": 0,
      "Science": 0,
      "Sports": 0,
      "Technology & Computing": 0,
      "Travel": 0

      # When using custom topics: Your specified topics with counts
      # "pricing": 5,
      # "deployment": 2,
      # "languages": 3
    }
  }
}
```

**Structure:**
- `segments` - Array of topic assignments per text segment
- `summary.overall` - Contains topic counts
  - **Default mode:** All 10 standard categories with counts
  - **Custom mode:** Your specified topics with counts
  - Categories/topics with `count > 0` indicate detected topics
  - Categories/topics with `count = 0` were not detected

**Access pattern:**
```python
if result.topics:
    # Get overall topic counts
    overall = result.topics.get('summary', {}).get('overall', {})

    # Filter to only detected topics (count > 0)
    detected = [topic for topic, count in overall.items() if count > 0]

    # Access specific topic count
    finance_count = overall.get('Business & Finance', 0)
    pricing_count = overall.get('pricing', 0)  # For custom topics
```

**Default Topic Categories (10 total):**
When no custom topics are specified, these categories are detected:
1. Business & Finance
2. Education
3. Entertainment
4. Events & Attractions
5. Food & Drink
6. News & Politics
7. Science
8. Sports
9. Technology & Computing
10. Travel

#### `summary`
```python
{
  "content": "Customer called to inquire about account permissions...",
  # Or with bullets:
  # "content": "• Point 1\n• Point 2\n• Point 3"
}
```

**Configuration:**
```python
SummarizationConfig(
    content_type="conversational",  # "auto", "informative", "conversational"
    summary_length="brief",          # "brief", "detailed"
    summary_type="paragraphs",       # "paragraphs", "bullets"
)
```

**Access pattern:**
```python
if result.summary:
    content = result.summary.get('content', '')
    print(f"Summary: {content}")
```

#### `chapters` (Auto-generated)
```python
[
  {
    "start_time": 0.0,
    "end_time": 120.5,
    "title": "Introduction and Problem Statement"
  },
  {
    "start_time": 120.5,
    "end_time": 245.0,
    "title": "Solution Discussion"
  }
]
```

#### `audio_events`
```python
[
  {
    "type": "music",
    "start_time": 0.0,
    "end_time": 5.2
  },
  {
    "type": "laughter",
    "start_time": 45.3,
    "end_time": 46.1
  }
]
```

**Event types:** `music`, `laughter`, `applause`, etc.

## 📤 Expected Output

When you run the audio intelligence example, you'll see:

```
======================================================================
AUDIO INTELLIGENCE - Sentiment + Summaries
======================================================================

Transcribing with audio intelligence...
   - Sentiment analysis
   - Topic Detection
   - Summarization

Job ID: 7zm3vjhm8p
Processing...

======================================================================
RESULTS
======================================================================

Transcript:
----------------------------------------------------------------------
SPEAKER UU: Hi. Thanks for calling our housing support. This is Alex. How can I help you today? Hi, Alex. I'm having trouble accessing my team dashboard. It keeps showing a permissions error. Oh, I'm sorry to hear that. Jordan, let me take a look. Can I confirm the email address associated with your account? Sure. It's Jordan at Skyline Group.com. Perfect. Thank you. Uh, I can see that your account is active, but your team role was recently changed to editor instead of admin, which would explain the permission issue. Um, I can either update your role or send a request to your current admin to grant full access. Which would you prefer? Um, if you could update it for me, that would be great. I've just switched your role back to admin. Uh, could you please refresh your browser and try opening the dashboard again? Yep. It's working now. Thank you. Awesome. While I have you, would you like me to walk you through our new reporting feature? It lets you create custom analytics dashboards in just a few clicks. Yeah, sure, that sounds super useful. I'll send you a quick tutorial link via email and if you like, we can schedule a 15 minute onboarding call to go over the advanced settings. Yeah, that would be perfect. I've booked you for tomorrow at 10 a.m. you'll get a confirmation email shortly. Is there anything else I can help you with today? No. That's all. Thanks again. Alex. You're welcome. Jordan, thanks for calling housing support and have a productive day.
----------------------------------------------------------------------

Sentiment: neutral

Topics:
   • Business & Finance
   • Technology & Computing

Summary:
   Key Topics:
   - Team dashboard access
   - Permissions error
   - Role change (editor vs admin)
   - Reporting feature tutorial
   - Onboarding call scheduling
   Discussion:
   - Jordan reported a permissions error when accessing the team dashboard for Skyline Group.
   - Alex identified that Jordan's role was changed from admin to editor, causing restricted access.
   - Alex updated Jordan's role back to admin, resolving the dashboard access issue.
   - Alex offered to introduce Jordan to a new reporting feature that enables custom analytics dashboards.
   - Alex sent a tutorial link via email and scheduled a 15-minute onboarding call for tomorrow at 10 a.m. to review advanced settings.

Audio intelligence analysis complete!
```

### What You See:

1. **Transcript** - Full conversation with speaker labels
2. **Sentiment** - Overall emotional tone (positive/negative/neutral)
3. **Topics** - Detected categories from the 10 standard topics
4. **Summary** - Structured summary with:
   - Key topics section (bullet points)
   - Detailed discussion points (when using `summary_length="detailed"`)

The summary format changes based on your config:
- `summary_type="bullets"` - Structured with sections and bullet points
- `summary_type="paragraphs"` - Continuous narrative text
- `summary_length="brief"` - Few sentences
- `summary_length="detailed"` - Comprehensive breakdown with sections

## ⏭️ Next Steps

- **[Multilingual & Translation](../05-multilingual-translation/)** - Work across languages
- **[Working with Results](../06-working-with-results/)** - Parse and visualize intelligence data
- **[Use Cases: Call Center Analytics](../../use-cases/call-center-analytics/)** - Production example

## 📚 Resources

- [Sentiment Analysis Docs](https://docs.speechmatics.com/speech-to-text/batch/speech-intelligence/sentiment-analysis)
- [Topic Detection Docs](https://docs.speechmatics.com/speech-to-text/batch/speech-intelligence/topics)
- [Summarization Docs](https://docs.speechmatics.com/speech-to-text/batch/speech-intelligence/summarization)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Batch only

[⬅️ Back to Basics](../README.md)
