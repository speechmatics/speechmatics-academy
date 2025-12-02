# Text-to-Speech - Your First TTS

**Convert text to natural-sounding speech using Speechmatics TTS API.**

Generate high-quality speech audio from text in under 5 minutes with minimal setup.

## What You'll Learn

- How to use the Speechmatics TTS SDK
- Generate speech from text with different voices
- Save audio output to WAV files
- Available voice options (UK/US English)

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**

## Quick Start

### Python

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

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API key**

```bash
cp ../.env.example .env
```

Open the `.env` file and add your API key:

```
SPEECHMATICS_API_KEY=your_actual_api_key_here
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Run the example**

```bash
python main.py
```

## How It Works

This is the complete code to generate speech:

### Python

```python
import asyncio
import os
from dotenv import load_dotenv
from speechmatics.tts import AsyncClient, Voice, OutputFormat

load_dotenv()

async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    text = "Hello! Welcome to Speechmatics text to speech."

    async with AsyncClient(api_key=api_key) as client:
        # Generate speech
        response = await client.generate(
            text=text,
            voice=Voice.SARAH,
            output_format=OutputFormat.WAV_16000,
        )

        # Read complete audio response and save to file
        audio_data = await response.read()
        with open("output.wav", "wb") as f:
            f.write(audio_data)

if __name__ == "__main__":
    asyncio.run(main())
```

## Available Voices

| Voice | Language | Gender | ID |
|-------|----------|--------|-----|
| **Sarah** | English (UK) | Female | `sarah` |
| **Theo** | English (UK) | Male | `theo` |
| **Megan** | English (US) | Female | `megan` |
| **Jack** | English (US) | Male | `jack` |

### Using Different Voices

```python
from speechmatics.tts import Voice

# UK Female
voice = Voice.SARAH

# UK Male
voice = Voice.THEO

# US Female
voice = Voice.MEGAN

# US Male (use string ID)
voice = "jack"
```

> [!NOTE]
> The `jack` voice may not be available in the Voice enum yet. Use the string `"jack"` directly.

## Output Formats

| Format | Description | Sample Rate |
|--------|-------------|-------------|
| `WAV_16000` | Complete WAV file | 16 kHz, 16-bit mono |
| `PCM_16000` | Raw PCM data | 16 kHz, 16-bit mono |

## Expected Output

```
Speechmatics Text-to-Speech Demo
========================================
Text: Hello! Welcome to Speechmatics text to speech. This is a demonstration of natural sounding speech synthesis.
Voice: Sarah (English UK Female)
Output: output.wav

Generating speech...
Audio saved to: assets/output.wav

Available voices:
  - sarah: English Female (UK)
  - theo: English Male (UK)
  - megan: English Female (US)
  - jack: English Male (US)
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Low Latency** | Under 200ms initial latency for streaming |
| **Natural Speech** | High-quality, natural-sounding voices |
| **Multiple Voices** | UK and US English male/female options |
| **Simple API** | Single method call to generate speech |

## How the Code Works

> [!NOTE]
> 1. **Load Environment** - Load your API key from `.env` file
> 2. **Define Text** - Set the text you want to convert to speech
> 3. **Create Client** - Initialize AsyncClient with your API key
> 4. **Generate** - Call `client.generate()` with text, voice, and output format
> 5. **Save Audio** - Read the response and write audio bytes to file

## Next Steps

Now that you have basic TTS working, explore:

- **[Hello World](../01-hello-world/)** - Transcribe audio (STT)
- **[Batch vs Real-time](../02-batch-vs-realtime/)** - Understand different STT modes
- **[LiveKit Voice Assistant](../../integrations/livekit/01-simple-voice-assistant/)** - Build a complete voice agent with STT + LLM + TTS

## Troubleshooting

**Error: "Invalid API key"**
- Check your `.env` file has the correct `SPEECHMATICS_API_KEY`
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)
- Make sure there are no extra spaces or quotes around the key

**Error: "Module not found"**
- Make sure you installed dependencies: `pip install -r requirements.txt`
- Verify you're in the activated virtual environment

**No audio output**
- Check the `assets/` folder for the `output.wav` file
- Try playing the file with your default audio player

## Resources

- [Speechmatics TTS Quickstart](https://docs.speechmatics.com/text-to-speech/quickstart)
- [Speechmatics TTS Product Page](https://www.speechmatics.com/text-to-speech)
- [API Reference](https://docs.speechmatics.com/api-ref/)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 5 minutes
**Difficulty**: Beginner
**SDK**: TTS

[Back to Basics](../) | [Back to Academy](../../README.md)
