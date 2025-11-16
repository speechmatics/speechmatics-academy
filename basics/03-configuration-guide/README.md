# Configuration Guide - All Options in One Place

**Comprehensive guide to all Speechmatics configuration options including diarization, custom vocabulary, and output formats.**

Stop searching through docs - all config options explained with working examples in one place!

## 🎯 What You'll Learn

- All available configuration parameters
- Speaker diarization setup
- Custom vocabulary for accuracy
- Output format options
- Punctuation and formatting controls
- Language and dialect selection

## 📋 Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- Completed [Hello World](../01-hello-world/) example

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
# Edit .env and add your SPEECHMATICS_API_KEY
python main.py
```

## ⚙️ Configuration Options

### 1. Speaker Diarization

**What it does**: Identifies and labels different speakers in the audio

```python
config = TranscriptionConfig(
    language="en",
    diarization="speaker",  # Enable speaker detection
    speaker_diarization_config={
        "max_speakers": 4  # Optional: limit number of speakers
    }
)
```

**Output**:
```
SPEAKER S1: Hello, how are you today?
SPEAKER S2: I'm doing great, thanks for asking!
```

### 2. Custom Vocabulary

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

**Pro tip**: Use `sounds_like` to provide phonetic alternatives for better recognition!

### 3. Punctuation & Entities

**What it does**: Controls punctuation and entity detection

```python
config = TranscriptionConfig(
    language="en",
    enable_entities=True,  # Detect dates, times, numbers, currencies
    punctuation_overrides={
        "permitted_marks": [".", "?", "!"]  # Custom punctuation rules
    }
)
```

### 4. Output Locale & Domain

**What it does**: Customize output language format and optimize for specific domains

```python
config = TranscriptionConfig(
    language="en",
    output_locale="en-US",  # RFC-5646 format
    domain="medical",       # Optimize for specific domain
)
```

**Available domains**:
- `medical` - Medical terminology

### 5. Language Settings

**What it does**: Specify language and enable auto-detection

```python
config = TranscriptionConfig(
    language="en",            # Primary language
    language_detection=True,  # Auto-detect if unsure
)
```

**Supported languages**: 50+ languages including English, Spanish, French, German, Japanese, Chinese, and more.

### 6. Operating Point

**What it does**: Balance between speed and accuracy

```python
config = TranscriptionConfig(
    language="en",
    operating_point="enhanced",  # or "standard"
)
```

- `standard` - Fast, good accuracy
- `enhanced` - Slower, best accuracy

## 💡 Complete Example

Here's an example combining multiple options:

```python
import asyncio
from speechmatics.batch import AsyncClient, TranscriptionConfig, OperatingPoint

async def main():
    api_key = "your_api_key_here"

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
            operating_point=OperatingPoint.ENHANCED,
        )

        # Transcribe with config
        result = await client.transcribe("audio.wav", transcription_config=config)
        print(result.transcript_text)

if __name__ == "__main__":
    asyncio.run(main())
```

## 📊 Configuration Cheat Sheet

| Category                      | Feature              | Config Parameter             | Values                                              | Description                                                                 |
|-------------------------------|----------------------|------------------------------|-----------------------------------------------------|-----------------------------------------------------------------------------|
| 🔵 **Core Settings**          | Language             | `language`                   | `"en"`, `"es"`, `"fr"`, etc. (default: `"en"`)      | ISO 639-1 language code for transcription                                   |
| 🔵 **Core Settings**          | Quality              | `operating_point`            | `OperatingPoint.STANDARD`, `ENHANCED` (default)     | Acoustic model to use - enhanced for best accuracy, standard for speed      |
| 🔵 **Core Settings**          | Output Locale        | `output_locale`              | RFC-5646 code (e.g., `"en-US"`)                     | Language code for transcript output formatting                              |
| 🔵 **Core Settings**          | Domain               | `domain`                     | `"medical"`, etc.                                   | Language pack optimized for specific domain                                 |
| 🟢 **Speech Recognition**     | Speaker Labels       | `diarization`                | `"speaker"`, `"channel"`, `"channel_and_speaker"`   | Type of diarization - identifies different speakers or channels             |
| 🟢 **Speech Recognition**     | Speaker Config       | `speaker_diarization_config` | Dict (e.g., `{"max_speakers": 4}`)                  | Advanced speaker settings like sensitivity and max speakers                 |
| 🟢 **Speech Recognition**     | Channel Labels       | `channel_diarization_labels` | List of strings (e.g., `["Agent", "Customer"]`)     | Custom labels for audio channels                                            |
| 🟢 **Speech Recognition**     | Custom Vocab         | `additional_vocab`           | List of dicts with `content`, `sounds_like`         | Additional vocabulary not in standard language pack                         |
| 🟡 **Formatting**             | Entity Detection     | `enable_entities`            | `True`/`False`                                      | Detect and format dates, times, numbers, currencies, etc.                   |
| 🟡 **Formatting**             | Punctuation          | `punctuation_overrides`      | Dict (e.g., `{"permitted_marks": [".", "?"]}`)      | Custom punctuation rules and permitted marks                                |
| 🟣 **Real-time**              | Partial Results      | `enable_partials`            | `True`/`False`                                      | Receive partial transcription results before finalization                   |
| 🟣 **Real-time**              | Max Delay            | `max_delay`                  | Float (seconds, e.g., `2.5`)                        | Maximum delay for transcript delivery (range: 0.7-4.0)                      |
| 🟣 **Real-time**              | Max Delay Mode       | `max_delay_mode`             | `"fixed"` or `"flexible"`                           | Fixed strictly adheres to max_delay, flexible allows override for entities  |

## 📤 Expected Output

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

## ⏭️ Next Steps

- **[Audio Intelligence](../04-audio-intelligence/)** - Add sentiment analysis and topics
- **[Multilingual & Translation](../05-multilingual-translation/)** - Work with multiple languages
- **[Working with Results](../06-working-with-results/)** - Parse and format output

## 🐛 Troubleshooting

**"max_speakers parameter invalid"**
- Value must be between 2 and 20
- Only works when `diarization="speaker"`

**"Custom vocabulary not working"**
- Ensure terms are spelled correctly
- Use `sounds_like` for ambiguous terms
- Limit to 1000 terms for best performance

**"Output format not supported"**
- Check you're using: `txt`, `json-v2`, `srt`, or `vtt`
- Some formats only available in batch mode

## 📚 Resources

- [Configuration Reference](https://docs.speechmatics.com/speech-to-text/configuration)
- [Supported Languages](https://docs.speechmatics.com/introduction/languages)
- [Output Formats](https://docs.speechmatics.com/speech-to-text/output-formats)

---

**Time to Complete**: 15 minutes
**Difficulty**: Beginner
**API Mode**: Batch (works with Real-time too)

[⬅️ Back to Basics](../README.md)
