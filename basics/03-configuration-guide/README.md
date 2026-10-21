# Configuration Guide - Common Configuration Options

**Guide to common Speechmatics configuration options including diarization, custom dictionary, and output formats.**

Stop searching through docs - common config options explained with working examples in one place!

## What You'll Learn

- Common configuration parameters
- Speaker diarization setup
- Custom dictionary for accuracy
- Output format options
- Punctuation and formatting controls
- Language and dialect selection

## Prerequisites

- **Speechmatics API key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.12**
- Completed [Hello World](../01-hello-world/) example

## Quick Start

**Step 1: Create and activate a virtual environment**

**On Windows (PowerShell):**
```powershell
cd python
python -m venv .venv
.\.venv\Scripts\Activate.ps1
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

## How It Works

> [!NOTE]
> This example demonstrates how to configure Speechmatics transcription:
>
> 1. **Create TranscriptionConfig** - Define all configuration parameters
> 2. **Set Language & Diarization** - Configure speaker detection
> 3. **Add Custom dictionary** - Improve accuracy for specific terms
> 4. **Enable Entities** - Detect dates, numbers, currencies
> 5. **Submit Transcription** - Send audio with configuration
> 6. **Process Results** - Extract transcript and detected entities
>
> The configuration system is flexible - start with defaults and add only what you need.

> [!TIP]
> **For latency-sensitive applications**, consider using the **Realtime API** (`speechmatics-rt`) instead of batch. Realtime streaming provides results as you speak, with latency controlled by model and configuration, making it ideal for live captioning, voice agents, and interactive applications. See [Batch vs Realtime](../02-batch-vs-realtime/) for a comparison.

## Configuration Options

### 1. Speaker Diarization

**What it does**: Separates speech from different speakers and assigns labels; speaker identification is the separate feature for recognizing known voices.

```python
config = TranscriptionConfig(
    language="en",
    diarization="speaker",  # Enable speaker detection
    speaker_diarization_config={
        "prefer_current_speaker": True  # Reduce frequent speaker label changes
    }
)
```

**Output**:
```
SPEAKER S1: Hello, how are you today?
SPEAKER S2: I'm doing great, thanks for asking!
```

> [!TIP]
> **About `prefer_current_speaker`**: This option biases the diarization towards the current speaker, reducing unnecessary speaker label switches. This is particularly beneficial for **captioning** and **live subtitling** where frequent speaker changes can be distracting to viewers. Widely used in broadcast and media applications.

> [!WARNING]
> **About `max_speakers`**: Use with caution. When set, the system forces all detected speakers into the specified number of groups. If you set `max_speakers=2` but there are actually 4 speakers, the system will incorrectly merge speakers together, causing **diarization errors** and unreliable speaker attribution. Only use this when you are **absolutely certain** about the exact speaker count (e.g., a controlled two-person interview). For most scenarios, **omit this setting entirely** and let the system automatically detect the number of speakers.
>
> ```python
> # Use max_speakers ONLY when you know the exact count
> speaker_diarization_config={
>     "max_speakers": 2  # Only if you're certain there are exactly 2 speakers
> }
> ```

### 2. Custom Dictionary

**What it does**: Improves accuracy for domain-specific terms

```python
config = TranscriptionConfig(
    language="en",
    additional_vocab=[
        {"content": "Speechmatics", "sounds_like": ["speech matics", "speech mattics"]},
        {"content": "transcription"},
        {"content": "API", "sounds_like": ["A P I", "ay pee eye"]},
        {"content": "demo"},
    ]
)
```

**Use cases**:
- Product names (e.g., "Speechmatics")
- Technical jargon (e.g., "API", "transcription")
- Industry-specific terms
- Acronyms and abbreviations

> [!TIP]
> Use `sounds_like` to provide phonetic alternatives for better recognition!

### 3. Punctuation & Entities

**What it does**: Controls punctuation and entity detection

```python
config = TranscriptionConfig(
    language="en",
    enable_entities=True,  # Detect dates, times, numbers, currencies
    punctuation_overrides={
        "sensitivity": 0.4,  # Control punctuation frequency (0.0-1.0)
        "permitted_marks": [".", "?", "!"]  # Limit allowed punctuation marks
    }
)
```

> [!TIP]
> **About `punctuation_sensitivity`**: This controls how frequently punctuation marks are inserted. A lower value (e.g., `0.2`) produces fewer punctuation marks, while a higher value (e.g., `0.8`) produces more. Useful for tuning output to your specific use case - for example, reducing punctuation for voice agent applications or increasing it for detailed transcripts.

### 4. Output Locale & Medical Sub-variant

**What it does**: Customize output language format and optimize for specific domains

```python
config = TranscriptionConfig(
    language="en",
    output_locale="en-US",  # RFC-5646 format
    domain="medical",       # Optimize for specific domain
)
```

**Medical sub-variant**: `domain="medical"` selects the Medical sub-variant of Enhanced. It is distinct from the multilingual Batch model Oak 1; see [model selection](https://docs.speechmatics.com/speech-to-text/models).

### 5. Language Settings

**What it does**: Specify language and enable language identification

```python
from speechmatics.batch import JobConfig, JobType, TranscriptionConfig, LanguageIdentificationConfig

config = JobConfig(
    type=JobType.TRANSCRIPTION,
    transcription_config=TranscriptionConfig(language="auto"),
    language_identification_config=LanguageIdentificationConfig(
        expected_languages=["en", "es", "fr"]  # Optional: hint at expected languages
    )
)
```

> [!NOTE]
> Language identification is configured at the `JobConfig` level, not inside `TranscriptionConfig`. The `expected_languages` parameter is optional - if omitted, all supported languages will be considered.

**Supported languages**: 50+ languages including English, Spanish, French, German, Japanese, Mandarin, and more.

### 6. Model Selection

**What it does**: Select the Standard or Enhanced model variant. The code below uses the older `operating_point` field for compatibility with this example. Current APIs prefer `model`; do not set both fields in one request.

```python
config = TranscriptionConfig(
    language="en",
    operating_point="enhanced",  # or "standard"
)
```

- `standard` - Fast, good accuracy
- `enhanced` - Slower, best accuracy

> [!TIP]
> Compare Standard and Enhanced on representative audio. Enhanced prioritizes accuracy; Standard prioritizes throughput. Turnaround and accuracy depend on your audio and configuration. See the [model comparison](https://docs.speechmatics.com/speech-to-text/models) for current capabilities.

## Complete Example

Here's an example combining multiple options:

```python
import asyncio
import os
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig, OperatingPoint

load_dotenv()

async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    async with AsyncClient(api_key=api_key) as client:
        # Comprehensive configuration
        config = TranscriptionConfig(
            language="en",

            # Speaker diarization
            diarization="speaker",

            # Custom vocabulary with phonetic alternatives
            additional_vocab=[
                {"content": "Speechmatics", "sounds_like": ["speech matics", "speech mattics"]},
                {"content": "transcription"},
                {"content": "API", "sounds_like": ["A P I", "ay pee eye"]},
                {"content": "demo"},
            ],

            # Formatting
            enable_entities=True,  # Detect dates, times, numbers

            # Quality
            operating_point="enhanced",
        )

        # Transcribe with config
        result = await client.transcribe("audio.wav", transcription_config=config)
        print(result.transcript_text)

if __name__ == "__main__":
    asyncio.run(main())
```

## Configuration Cheat Sheet

| Category                      | Feature              | Config Parameter             | Values                                              | Description                                                                 |
|-------------------------------|----------------------|------------------------------|-----------------------------------------------------|-----------------------------------------------------------------------------|
| **Core Settings**          | Language             | `language`                   | `"en"`, `"es"`, `"fr"`, etc. (default: `"en"`)      | ISO 639-1 language code for transcription                                   |
| **Core Settings**          | Quality              | `operating_point`            | `OperatingPoint.STANDARD`, `ENHANCED` (default)     | Acoustic model to use - enhanced for best accuracy, standard for speed      |
| **Core Settings**          | Output Locale        | `output_locale`              | RFC-5646 code (e.g., `"en-US"`)                     | Language code for transcript output formatting                              |
| **Core Settings**          | Domain               | `domain`                     | `"medical"`, etc.                                   | Language pack optimized for specific domain                                 |
| **Speech Recognition**     | Speaker Labels       | `diarization`                | `"speaker"`, `"channel"`, `"channel_and_speaker"`   | Type of diarization - identifies different speakers or channels             |
| **Speech Recognition**     | Prefer Current Speaker | `speaker_diarization_config.prefer_current_speaker` | `True`/`False`                                | Bias towards current speaker - reduces label switching (great for captions) |
| **Speech Recognition**     | Max Speakers         | `speaker_diarization_config.max_speakers`           | Integer (e.g., `2`, `4`)                      | Upper limit on detected speakers; does not force an exact count             |
| **Speech Recognition**     | Speaker Sensitivity  | `speaker_diarization_config.speaker_sensitivity`    | Float `0.0`-`1.0`                             | Diarization sensitivity - higher values help distinguish similar voices     |
| **Speech Recognition**     | Channel Labels       | `channel_diarization_labels` | List of strings (e.g., `["Agent", "Customer"]`)     | Custom labels for audio channels                                            |
| **Speech Recognition**     | Custom dictionary    | `additional_vocab`           | List of dicts with `content`, `sounds_like`         | Additional vocabulary not in standard language pack                         |
| **Formatting**             | Entity Detection     | `enable_entities`            | `True`/`False`                                      | Detect and format dates, times, numbers, currencies, etc.                   |
| **Formatting**             | Punctuation Sensitivity | `punctuation_overrides.sensitivity`              | Float `0.0`-`1.0` (e.g., `0.4`)               | Control punctuation frequency - lower = fewer marks, higher = more marks    |
| **Formatting**             | Permitted Marks      | `punctuation_overrides.permitted_marks`             | List (e.g., `[".", ",", "?"]`)                      | Limit which punctuation marks are allowed in output                         |
| **Real-time**              | Partial Results      | `enable_partials`            | `True`/`False`                                      | Receive partial transcription results before finalization                   |
| **Real-time**              | Max Delay            | `max_delay`                  | Float (seconds, e.g., `2.5`)                        | Duration the engine waits to verify partial word accuracy before committing to final output (range: 0.7-4.0) |
| **Real-time**              | Max Delay Mode       | `max_delay_mode`             | `"fixed"` or `"flexible"`                           | Fixed strictly adheres to max_delay, flexible allows override for entities  |

## Expected Output

```
======================================================================
SPEECHMATICS CONFIGURATION GUIDE
======================================================================

 Configuration:
   Language: en
   Diarization: speaker
   Custom vocabulary: 4 terms
   Entity detection: True
   Operating point: OperatingPoint.ENHANCED

 Transcribing with full configuration...

======================================================================
RESULTS
======================================================================

Transcript:
SPEAKER S1: Welcome to Speechmatics transcription API demo.
SPEAKER S2: This example shows multiple configuration options in action.
SPEAKER S1: Today is January 15th, 2025 at 3:30 p.m..
SPEAKER S2: The meeting will cost approximately $500 for the project.

Detected Entities:
----------------------------------------------------------------------
   • January 15th @ 8.48s
   • 2025 @ 9.64s
   • 3:30 p.m. @ 11.20s
   • $500 @ 15.80s

(Entity types: date, time, money, percentage, cardinal)

 Configuration demo complete!

 This example showed:
   • Speaker diarization
   • Custom vocabulary with phonetic alternatives (sounds_like)
   • Entity detection (dates, times, numbers, etc.)
   • Enhanced accuracy mode
```

## Key Features Demonstrated

**Speaker Diarization:**
- Automatic speaker detection and labeling
- Support for multi-speaker scenarios
- `prefer_current_speaker` for stable captioning (reduces label switching)
- Optional `max_speakers` limit (use with caution)

**Custom dictionary:**
- Domain-specific term accuracy
- Phonetic alternatives with sounds_like
- Support for acronyms and product names

**Entity Detection:**
- Automatic formatting of dates, times, numbers
- Currency detection and formatting
- Structured spoken-value entities, such as dates and currencies; this is not general person or organization extraction

**Quality Settings:**
- Operating point configuration (Enhanced vs Standard)
- Language and dialect selection
- Output locale customization

## Next Steps

- **[Audio Intelligence](../04-audio-intelligence/)** - Add sentiment analysis and topics
- **[Multilingual & Translation](../05-multilingual-translation/)** - Work with multiple languages
- **[Turn Detection](../07-turn-detection/)** - Real-time turn detection for conversations

## Troubleshooting

**"max_speakers parameter invalid"**
- Value must be greater than or equal to 2
- Only works when `diarization="speaker"`

**Diarization errors / speakers being merged incorrectly**
- If you're using `max_speakers` and seeing incorrect speaker attribution, **remove it**
- `max_speakers` forces the system to fit all speakers into that number, causing merging errors if the actual count is higher
- For unknown speaker counts, omit `max_speakers` entirely and let auto-detection handle it
- Consider using `prefer_current_speaker: True` instead for more stable speaker labels

**"Custom dictionary not working"**
- Ensure terms are spelled correctly
- Use `sounds_like` for ambiguous terms
- Limit to 1000 terms for best performance

**"Output format not supported"**
- The Batch API returns `txt`, `json-v2`, or `srt`. Convert SRT separately if you need WebVTT.
- Some formats only available in batch mode

## Resources

- [Formatting Reference](https://docs.speechmatics.com/speech-to-text/formatting)
- [Supported Languages](https://docs.speechmatics.com/speech-to-text/languages)
- [Output Formats](https://docs.speechmatics.com/speech-to-text/batch/output)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Beginner
**API Mode**: Batch; Realtime settings are identified separately

[Back to Basics](../) | [Back to Academy](../../README.md)
