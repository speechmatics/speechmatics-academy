# Hello World - Your First Transcription

**The absolute simplest Speechmatics example - transcribe an audio file.**

Get your first transcription working in under 5 minutes with minimal setup.

## 🎯 What You'll Learn

- How to make your first API call to Speechmatics
- The minimum code required for transcription
- How to get a basic transcript from an audio file

## 📋 Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Audio file**: We'll use a sample WAV file (provided)

## 🚀 Quick Start

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

**Step 2: Install dependencies and run**

```bash
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
python main.py
```



## 💡 How It Works

This is the complete code to transcribe audio:

### Python

```python
import asyncio
import os
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, AuthenticationError

# Load environment variables
load_dotenv()


async def main():
    """Transcribe an audio file """

    # Get API key from environment
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    # Path to sample audio file
    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    print("Transcribing audio file...")
    print(f"File: {audio_file.name}")
    print()

    try:
        # Initialize client and transcribe
        async with AsyncClient(api_key=api_key) as client:
            # Transcribe - this is the simplest way!
            result = await client.transcribe(str(audio_file))
            # Print the transcript
            print(result.transcript_text)
       
    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```


## 📤 Expected Output

```
Hello, this is a sample audio transcription. Welcome to Speechmatics!
```

## 🔍 What's Happening

1. **Load Environment** - Load your API key from `.env` file using dotenv
2. **Get API Key** - Retrieve API key from environment variables with validation
3. **Locate Audio File** - Use Path to find the sample audio file
4. **Create Async Client** - Initialize AsyncClient with your API key
5. **Transcribe** - Send audio file to the API using `await client.transcribe()`
6. **Get Results** - Access the transcript using `result.transcript_text`

The code uses async/await for better performance and proper resource management with context managers.

## ⏭️ Next Steps

Now that you have basic transcription working, explore:

- **[Batch vs Real-time](../02-batch-vs-realtime/)** - Understand different API modes
- **[Configuration Guide](../03-configuration-guide/)** - Add diarization, custom vocabulary, etc.
- **[Audio Intelligence](../04-audio-intelligence/)** - Get sentiment, topics, and summaries

## 🐛 Troubleshooting

**Error: "Invalid API key"**
- Check your `.env` file has the correct `SPEECHMATICS_API_KEY`
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)

**Error: "File not found"**
- Make sure `sample.wav` is in the same directory
- Try using an absolute path: `/full/path/to/sample.wav`

**No output / Empty transcript**
- Check your audio file has audible speech
- Verify the audio format is supported (WAV, MP3, M4A, etc.)

## 📚 Resources

- [Speechmatics Batch API Docs](https://docs.speechmatics.com/introduction/batch-guide)
- [Supported Audio Formats](https://docs.speechmatics.com/introduction/audio-formats)
- [API Reference](https://docs.speechmatics.com/batch-api-ref)

---

**Time to Complete**: 5 minutes
**Difficulty**: Beginner
**API Mode**: Batch

[⬅️ Back to Basics](../README.md)
