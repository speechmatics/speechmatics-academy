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

### 🔵 Core Settings

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `language` | `"en"`, `"es"`, `"fr"`, `"de"`, `"ja"`, etc. | `"en"` | **ISO 639-1 language code**<br>Specify the primary language for transcription. [See all supported languages →](https://docs.speechmatics.com/introduction/languages) |
| `operating_point` | `OperatingPoint.STANDARD`, `OperatingPoint.ENHANCED` | `ENHANCED` | **Acoustic model selection**<br>**enhanced** - Best accuracy, slightly slower<br>**standard** - Faster processing, good accuracy |
| `output_locale` | RFC-5646 codes (e.g., `"en-US"`, `"en-GB"`) | Same as `language` | **Output formatting locale**<br>Controls number formatting, date formats, and other locale-specific output |
| `domain` | `"medical"`, `"finance"`, etc. | None | **Domain-optimized language pack**<br>Use specialized vocabulary for specific industries |

### 🟢 Speech Recognition

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `diarization` | `"speaker"`, `"channel"`, `"channel_and_speaker"`, `"none"` | `"none"` | **Speaker/channel identification**<br>**speaker** - Identify different speakers in single-channel audio<br>**channel** - Label separate audio channels<br>**channel_and_speaker** - Identify speakers within each channel<br>**none** - No speaker labeling |
| `speaker_diarization_config` | Dict: `{"max_speakers": int}` | `{}` | **Advanced speaker settings**<br>**max_speakers** (2-20) - Limit number of detected speakers<br>Only applies when `diarization="speaker"` |
| `channel_diarization_labels` | List of strings (e.g., `["Agent", "Customer"]`) | None | **Custom channel labels**<br>Replace generic "Channel 1/2" with meaningful labels<br>Length must match number of audio channels |
| `additional_vocab` | List of dicts with `content`, `sounds_like` | `[]` | **Custom vocabulary terms**<br>Add domain-specific words, product names, acronyms<br>Format: `[{"content": "word", "sounds_like": ["phonetic1", "phonetic2"]}]`<br>Limit: 1000 terms for optimal performance |

### 🟡 Formatting

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `enable_entities` | `True`, `False` | `False` | **Automatic entity detection and formatting**<br>Detects and formats:<br>• Dates (e.g., "January 15th")<br>• Times (e.g., "3:30 p.m.")<br>• Numbers (e.g., "1,234")<br>• Currency (e.g., "$500")<br>• Percentages (e.g., "25%") |
| `punctuation_overrides` | Dict: `{"permitted_marks": list}` | All marks enabled | **Custom punctuation rules**<br>**permitted_marks** - Limit which punctuation marks appear in transcript<br>Example: `{"permitted_marks": [".", "?", "!"]}` |

### 🟣 Real-time Only

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `enable_partials` | `True`, `False` | `False` | **Streaming partial results**<br>Receive intermediate transcription results before finalization<br>Useful for live captions and real-time feedback |
| `max_delay` | Float (0.7 - 4.0 seconds) | `4.0` | **Maximum transcript delivery delay**<br>Lower values = faster results, may reduce accuracy<br>Higher values = better accuracy, slower results<br>Recommended: 2.0-3.0 for balanced performance |
| `max_delay_mode` | `"fixed"`, `"flexible"` | `"fixed"` | **Delay enforcement mode**<br>**fixed** - Strictly adheres to max_delay setting<br>**flexible** - May exceed max_delay for entity detection/formatting |

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
