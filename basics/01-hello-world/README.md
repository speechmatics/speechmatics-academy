# Hello World - Your First Transcription

**The absolute simplest Speechmatics example - transcribe an audio file.**

Get your first transcription working in under 5 minutes with minimal setup.

## What You'll Learn

- How to make your first API call to Speechmatics
- The minimum code required for transcription
- How to get a basic transcript from an audio file

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Audio file**: We'll use a sample WAV file (provided)

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


## Expected Output

```
Hello, this is a sample audio transcription. Welcome to Speechmatics!
```

## Key Features Demonstrated

**Minimal Setup:**
- Single API call for transcription
- Automatic audio format detection
- No configuration required

**Async/Await Pattern:**
- Non-blocking I/O for better performance
- Proper resource management with context managers

**Error Handling:**
- Authentication error catching
- Clear error messages

## How the Code Works
> [!NOTE]
> 1. **Load Environment** - Load your API key from `.env` file using dotenv
> 2. **Get API Key** - Retrieve API key from environment variables with validation
> 3. **Locate Audio File** - Use Path to find the sample audio file
> 4. **Create Async Client** - Initialize AsyncClient with your API key
> 5. **Transcribe** - Send audio file to the API using `await client.transcribe()`
> 6. **Get Results** - Access the transcript using `result.transcript_text`
>
> The code uses async/await for better performance and proper resource management with context managers.

## Next Steps

Now that you have basic transcription working, explore:

- **[Batch vs Real-time](../02-batch-vs-realtime/)** - Understand different API modes
- **[Configuration Guide](../03-configuration-guide/)** - Add diarization, custom vocabulary, etc.
- **[Audio Intelligence](../04-audio-intelligence/)** - Get sentiment, topics, and summaries

## Troubleshooting

**Error: "Invalid API key"**
- Check your `.env` file has the correct `SPEECHMATICS_API_KEY`
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)
- Make sure there are no extra spaces or quotes around the key

**Error: "File not found"**
- Make sure `sample.wav` is in the `assets/` directory
- Try using an absolute path: `/full/path/to/sample.wav`

**No output / Empty transcript**
- Check your audio file has audible speech
- Verify the audio format is supported (WAV, MP3, M4A, etc.)

## Resources

- [Speechmatics Batch API Docs](https://docs.speechmatics.com/introduction/batch-guide)
- [Supported Audio Formats](https://docs.speechmatics.com/speech-to-text/batch/input#supported-file-types)
- [API Reference](https://docs.speechmatics.com/api-ref/)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 5 minutes
**Difficulty**: Beginner
**API Mode**: Batch

[Back to Basics](../) | [Back to Academy](../../README.md)
