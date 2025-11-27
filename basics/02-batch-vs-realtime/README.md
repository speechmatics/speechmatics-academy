# Batch vs Real-time - Understanding API Modes

**Learn the difference between batch and real-time transcription modes and when to use each.**

This example shows both modes side-by-side so you understand which to use for your use case.

## What You'll Learn

- The difference between batch and real-time transcription
- When to use batch mode vs real-time mode
- How to implement both approaches
- Performance and cost tradeoffs

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Microphone** (for real-time example)

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

**Step 2: Install dependencies and run**

```bash
pip install -r requirements.txt
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY

# Try batch mode
python batch_example.py

# Try real-time mode
python realtime_example.py
```

## Batch vs Real-time

### Batch Mode

**Best for:**
- Pre-recorded audio/video files
- Processing large volumes of files
- When you can wait for results (minutes)
- Highest accuracy (post-processing applied)
- Cost-effective for large files

**How it works:**
1. Upload entire audio file
2. Server processes the complete file
3. Wait for processing (async)
4. Download complete transcript

**Example use cases:**
- Podcast transcription
- Meeting recordings
- Video subtitle generation
- Call center recordings

### Real-time Mode

**Best for:**
- Live audio streams
- When you need immediate results (< 1 second)
- Interactive applications
- Microphone input
- Live captioning

**How it works:**
1. Open WebSocket connection
2. Stream audio chunks continuously
3. Receive partial and final transcripts in real-time
4. Close connection when done

**Example use cases:**
- Live captioning
- Voice assistants
- Phone calls
- Live events

## Side-by-Side Comparison

### Batch Example

```python
import asyncio
import os
import time
from pathlib import Path
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig, OperatingPoint, AuthenticationError

# Load environment variables
load_dotenv()

async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    audio_file = Path(__file__).parent.parent / "assets" / "sample.wav"

    # Display file information
    file_size_bytes = audio_file.stat().st_size
    file_size_mb = file_size_bytes / (1024 * 1024)

    print(f"Processing file: {audio_file.name}")
    print(f"File size: {file_size_mb:.1f} MB")
    print()
    print("[... processing ...]")
    print()

    try:
        # Track processing time
        start_time = time.time()

        # Initialize batch client
        async with AsyncClient(api_key=api_key) as client:
            # Configure transcription
            config = TranscriptionConfig(
                language="en",
                operating_point=OperatingPoint.ENHANCED,
            )

            # Transcribe with batch API
            result = await client.transcribe(
                str(audio_file),
                transcription_config=config,
            )

        # Calculate actual processing time
        end_time = time.time()
        processing_time = end_time - start_time
        minutes = int(processing_time // 60)
        seconds = int(processing_time % 60)

        print(f"Complete! Processing time: {minutes}m {seconds}s")
        print()

        # Extract and display transcript
        transcript = result.transcript_text
        print("Full transcript:")
        print(f'"{transcript}"')

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Real-time Example

```python
import asyncio
import os
from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncClient,
    ServerMessageType,
    TranscriptionConfig,
    TranscriptResult,
    OperatingPoint,
    AudioFormat,
    AudioEncoding,
    Microphone,
    AuthenticationError,
)

# Load environment variables
load_dotenv()


async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    # Store transcript parts for final output
    transcript_parts = []

    # Configure audio format for microphone input
    audio_format = AudioFormat(
        encoding=AudioEncoding.PCM_S16LE,
        chunk_size=4096,
        sample_rate=16000,
    )

    # Configure transcription with partials enabled
    transcription_config = TranscriptionConfig(
        language="en",
        enable_partials=True,
        operating_point=OperatingPoint.ENHANCED,
    )

    # Initialize microphone
    mic = Microphone(
        sample_rate=audio_format.sample_rate,
        chunk_size=audio_format.chunk_size,
    )

    # Start microphone capture
    if not mic.start():
        print("PyAudio not installed. Install: pip install pyaudio")
        return

    try:
        # Initialize real-time client
        async with AsyncClient(api_key=api_key) as client:
            # Handle final transcripts
            @client.on(ServerMessageType.ADD_TRANSCRIPT)
            def handle_final_transcript(message):
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    print(f"[final]: {transcript}")
                    transcript_parts.append(transcript)

            # Handle partial transcripts (interim results)
            @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
            def handle_partial_transcript(message):
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    print(f"[partial]: {transcript}")

            try:
                print("Connected! Start speaking (Ctrl+C to stop)...\n")

                # Start transcription session
                await client.start_session(
                    transcription_config=transcription_config,
                    audio_format=audio_format,
                )

                # Stream audio continuously
                while True:
                    frame = await mic.read(audio_format.chunk_size)
                    await client.send_audio(frame)

            except KeyboardInterrupt:
                pass
            finally:
                # Clean up microphone
                mic.stop()
                print(f"\n\nFull transcript: {' '.join(transcript_parts)}")

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")


if __name__ == "__main__":
    asyncio.run(main())
```

## Performance Comparison

| Feature | Batch | Real-time |
|---------|-------|-----------|
| **Latency** | Minutes | < 1 second |
| **Accuracy** | Highest | Very high |
| **Cost** | Lower | Higher |
| **Use Case** | Pre-recorded | Live streams |
| **Max File Size** | Large (hours) | Unlimited stream |
| **Partial Results** | No | Yes |


## Decision Matrix

> [!IMPORTANT]
> **Use Batch if:**
> - You have a complete audio file
> - You can wait for results
> - You want highest accuracy
> - You're processing in bulk
>
> **Use Real-time if:**
> - You're streaming live audio
> - You need immediate feedback
> - You're building interactive apps
> - You need partial results

## Key Features Demonstrated

**Batch Mode:**
- File-based transcription with AsyncClient
- Complete file processing with wait for results
- Enhanced accuracy with OperatingPoint configuration
- Processing time measurement

**Real-time Mode:**
- WebSocket streaming with live audio
- Partial and final transcript events
- Microphone integration with PyAudio
- Event-driven architecture with decorators

**Comparison:**
- Performance tradeoffs (latency vs accuracy)
- Use case decision matrix
- Side-by-side code examples

## Expected Output

### Batch Output
```
Processing file: sample.wav
File size: 0.7 MB

[... processing ...]

Complete! Processing time: 0m 5s

Full transcript:
"SPEAKER UU: Good morning, everyone. Let's begin today's meeting."
```

### Real-time Output
```
Connected! Start speaking (Ctrl+C to stop)...

[partial]: Good morning
[partial]: Good morning everyone
[partial]: Good morning. Everyone. Let's begin
[partial]: Good morning, everyone. Let's begin. Today's
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[partial]: Good morning, everyone. Let's begin today's meeting
[final]: Good morning,
[partial]: everyone. Let's begin today's meeting.
[final]: everyone.
[partial]: Let's begin today's meeting.
[final]: Let's
[partial]: begin today's meeting.
[final]: begin
[partial]: today's meeting.
[final]: today's
[partial]: meeting.
[final]: meeting.


Full transcript: Good morning,  everyone.  Let's  begin  today's  meeting.
```

## Next Steps

- **[Configuration Guide](../03-configuration-guide/)** - Learn all config options for both modes
- **[Audio Intelligence](../04-audio-intelligence/)** - Add sentiment and insights
- **[Turn Detection](../07-turn-detection/)** - Real-time turn detection for conversations
- **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** - Advanced presets for voice agents

## Troubleshooting

**Batch: "Processing timeout"**
- Check file size (very large files take longer)
- Verify file format is supported
- Try polling for results instead of blocking

**Real-time: "WebSocket connection failed"**
- Verify your API key is valid
- Check network/firewall settings
- Ensure WebSocket connections are allowed

**Real-time: "Audio chunks too fast/slow"**
- Match audio streaming rate to real-time
- Use proper audio format (16kHz, mono, PCM)

## Resources

- [Batch API Reference](https://docs.speechmatics.com/batch-api-ref)
- [Real-time API Reference](https://docs.speechmatics.com/rt-api-ref)
- [When to Use Which Mode](https://docs.speechmatics.com/introduction/overview)

---

**Time to Complete**: 10 minutes
**Difficulty**: Beginner
**API Modes**: Batch & Real-time

[Back to Basics](../README.md)
