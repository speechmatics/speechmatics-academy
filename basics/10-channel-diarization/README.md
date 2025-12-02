# Channel Diarization

**Transcribe multi-channel audio with channel-based speaker attribution using the RT SDK.**

Learn how to process stereo or multi-track recordings where each channel represents a different audio source (e.g., call center recordings with agent on one channel, customer on another).

## What You'll Learn

- Multi-channel transcription with `AsyncMultiChannelClient`
- Channel diarization configuration
- Custom channel labels for speaker attribution
- Using `TranscriptResult.from_message()` for parsing results

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+**
- **Two mono WAV files** (one per channel) - samples provided in `assets/`

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

**Step 3: Configure API key**

```bash
cp .env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run the example**

```bash
python main.py
```

## How It Works

> [!NOTE]
> Each audio file represents one channel. The SDK labels transcripts with the channel name you provide, enabling clear speaker attribution.

### Code Walkthrough

**1. Configure Multi-Channel Transcription**

```python
from speechmatics.rt import (
    AsyncMultiChannelClient,
    ServerMessageType,
    TranscriptionConfig,
    TranscriptResult,
)

LABELS = ["Customer", "Agent"]

config = TranscriptionConfig(
    language="en",
    diarization="channel",
    channel_diarization_labels=LABELS,
)
```

**2. Provide Channel Sources**

```python
sources = {
    "channel1": io.BytesIO(get_pcm(customer_file)),  # Maps to "Customer"
    "channel2": io.BytesIO(get_pcm(agent_file)),     # Maps to "Agent"
}
```

**3. Handle Transcripts**

```python
done = asyncio.Event()

async with AsyncMultiChannelClient(api_key=api_key) as client:

    @client.on(ServerMessageType.ADD_TRANSCRIPT)
    def on_transcript(msg):
        result = TranscriptResult.from_message(msg)
        channel = msg.get("channel")  # "Customer" or "Agent"
        print(f"{channel}: {result.metadata.transcript}")

    @client.on(ServerMessageType.END_OF_TRANSCRIPT)
    def on_end(msg):
        done.set()

    await client.transcribe(sources=sources, transcription_config=config)
    await done.wait()
```

## Expected Output

```
Transcribing...

[00:00] Customer: Hi.
[00:00] Agent: Thank you
[00:01] Customer: I need help
[00:01] Agent: for calling support.
[00:02] Customer: with my account. Great.
[00:02] Agent: I'd be happy to help you with that.
[00:05] Customer: My account number is 12345.

==================================================
SUMMARY
==================================================

Customer: Hi. I need help with my account. Great. My account number is 12345.

Agent: Thank you for calling support. I'd be happy to help you with that.
```

## Key Features Demonstrated

- **Channel Separation**: Each audio file is treated as a separate channel
- **Custom Labels**: Human-readable names (Customer, Agent) instead of channel1/channel2
- **Structured Results**: Using `TranscriptResult.from_message()` for typed access
- **Real-time Processing**: Transcripts arrive as audio is processed

## Next Steps

- **[Voice Agent Speaker ID](../09-voice-agent-speaker-id/)** - Speaker identification and focus modes
- **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** - Intelligent turn detection
- **[Configuration Guide](../03-configuration-guide/)** - All configuration options

## Troubleshooting

**"File not found" error**
- Ensure `Agent.wav` and `Customer.wav` exist in `assets/` folder
- Files must be WAV format

**"Invalid audio format"**
- Each channel file should be mono (1 channel)
- Sample rate should be 16kHz
- Use PCM 16-bit encoding

**"Authentication failed"**
- Verify API key in `.env` file
- Check your key at [portal.speechmatics.com](https://portal.speechmatics.com/)

**No transcription output**
- Ensure audio files contain speech
- Check file duration (very short files may not produce results)

## Resources

- [Speechmatics Diarization Docs](https://docs.speechmatics.com/features/diarization)
- [RT SDK Reference](https://github.com/speechmatics/speechmatics-python-sdk)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Beginner
**API Mode**: RT Multi-Channel
**Languages**: Python

[Back to Basics](../) | [Back to Academy](../../README.md)
