# Turn Detection - Detect When Speech Ends

**Automatically detect when a speaker has finished speaking using silence-based turn detection.**

Perfect for voice AI, conversational agents, dictation systems, and interactive voice applications.

## What You'll Learn

- How turn detection works in real-time transcription
- Configuring silence thresholds for different use cases
- Handling end-of-utterance events
- Building responsive voice interactions
- Optimizing for voice AI vs dictation workflows

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.8+**
- **Microphone**: Built-in or external microphone
- **PyAudio**: For microphone access
- Completed previous basics examples

## Quick Start

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

> [!NOTE]
> If PyAudio installation fails, see [PyAudio Installation Issues](#pyaudio-installation-issues) in Troubleshooting.

Speak into your microphone and pause to trigger turn detection!

## How It Works

> [!NOTE]
> Turn detection uses silence-based analysis to identify when a speaker has finished speaking:
>
> 1. **Speech detected** - A countdown timer starts
> 2. **More words arrive** - Timer resets
> 3. **Silence threshold reached** - `EndOfUtterance` event triggers
> 4. **New utterance begins** - Process repeats

### Configuration

```python
from speechmatics.rt import TranscriptionConfig, ConversationConfig

# Configure turn detection
config = TranscriptionConfig(
    language="en",
    enable_partials=True,
    conversation_config=ConversationConfig(
        end_of_utterance_silence_trigger=0.7  # 700ms silence
    )
)
```

### Silence Threshold Recommendations

| Use Case | Threshold | Description |
|----------|-----------|-------------|
| Voice AI / Assistants | 0.5-0.8s | Quick response for interactive conversations |
| Dictation | 0.8-1.2s | Longer pauses for natural dictation flow |
| Custom | 0-2.0s | Adjust based on your application needs |

> [!TIP]
> Setting to `0` disables turn detection entirely.

> [!NOTE]
> The silence threshold serves as a **reference point**. In FIXED mode, the system waits precisely this duration. In ADAPTIVE mode (Voice SDK), this reference is dynamically modified based on speech characteristics - speakers with slower pace receive extended wait times, while rapid speakers trigger faster finalization.

## Event Handling

### EndOfUtterance Event

Triggered when silence threshold is reached:

```python
@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_end_of_utterance(message):
    """Called when speaker finishes speaking."""
    print("Turn detected!")

    # Message structure:
    # {
    #     "message": "EndOfUtterance",
    #     "end_of_utterance_time": 12.5  # Timestamp when silence was detected
    # }
```

> [!Important]
> The `end_of_utterance_time` represents when silence was detected, not the utterance duration. To calculate duration, track the start time from your first transcript.

### Calculating Utterance Duration

To get the actual duration of an utterance, track the start time from the first transcript:

```python
utterance_start_time = None
current_utterance = []

@client.on(ServerMessageType.ADD_TRANSCRIPT)
def handle_transcript(message):
    nonlocal utterance_start_time
    result = TranscriptResult.from_message(message)
    transcript = result.metadata.transcript
    if transcript:
        # Track start time of first segment
        if not current_utterance:
            utterance_start_time = result.metadata.start_time
        current_utterance.append(transcript.strip())

@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_end_of_utterance(message):
    nonlocal utterance_start_time
    if current_utterance and utterance_start_time is not None:
        full_text = " ".join(current_utterance)

        # END_OF_UTTERANCE has end_of_utterance_time directly in message
        end_time = message.get("end_of_utterance_time", 0)
        duration = end_time - utterance_start_time

        print(f"Turn: {full_text} ({duration:.2f}s)")

        current_utterance.clear()
        utterance_start_time = None
```

### Force End of Utterance

Manually trigger turn detection from client:

```python
# Send ForceEndOfUtterance message
await client.send_message({
    "message": ClientMessageType.FORCE_END_OF_UTTERANCE
})
```

This is useful for:
- Button-based "done speaking" interactions
- Timeout-based forced completion
- Multi-modal input handling

## Expected Output

When you run the example and speak:

```
======================================================================
TURN DETECTION
======================================================================

Speak and pause to trigger turn detection...
Press Ctrl+C to stop

> Hello, how are you today?

Turn 1: Hello, how are you today? (2.34s)

> I'm testing turn detection.

Turn 2: I'm testing turn detection. (1.87s)

> This is working great!

Turn 3: This is working great! (1.52s)

^C

Session ended

======================================================================
DETECTED 3 TURNS
======================================================================
1. Hello, how are you today? (2.34s)
2. I'm testing turn detection. (1.87s)
3. This is working great! (1.52s)
```

## Key Features Demonstrated

**Turn Detection:**
- Automatic end-of-utterance detection using silence thresholds
- Configurable silence triggers (0.5s-1.5s)
- Real-time event notifications with END_OF_UTTERANCE

**Event-Driven Architecture:**
- ADD_PARTIAL_TRANSCRIPT for real-time feedback
- ADD_TRANSCRIPT for final transcriptions
- END_OF_UTTERANCE for turn completion

**Timing and Metrics:**
- Track utterance start and end times
- Calculate turn duration
- Collect multiple turns with metadata

**Use Case Optimization:**
- Fast response for voice assistants (0.5-0.7s)
- Natural pauses for dictation (1.0s+)
- Balanced approach for conversations (0.7-0.9s)

## Use Cases

### Voice Assistants

```python
# Quick response with 500ms threshold
config = TranscriptionConfig(
    language="en",
    conversation_config=ConversationConfig(
        end_of_utterance_silence_trigger=0.5
    )
)

@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_turn(message):
    # Process user query immediately
    if current_utterance:
        user_query = " ".join(current_utterance)
        response = generate_ai_response(user_query)
        current_utterance.clear()
    speak(response)
```

### Dictation Systems

```python
# Allow natural pauses with 1.0s threshold
config = TranscriptionConfig(
    language="en",
    conversation_config=ConversationConfig(
        end_of_utterance_silence_trigger=1.0
    )
)

@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_turn(message):
    # Save completed sentence
    if current_utterance:
        sentence = " ".join(current_utterance)
        save_sentence(sentence)
        current_utterance.clear()
```

### Interactive Translation

```python
# Detect turns for live translation
@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_turn(message):
    # Translate completed utterance
    if current_utterance:
        source_text = " ".join(current_utterance)
        translated = translate(source_text)
        display_translation(translated)
        current_utterance.clear()
```

## Advanced Features

### Combining with Speaker Diarization

```python
from speechmatics.rt import SpeakerDiarizationConfig

config = TranscriptionConfig(
    language="en",
    diarization="speaker",
    speaker_diarization_config=SpeakerDiarizationConfig(
        max_speakers=2
    ),
    conversation_config=ConversationConfig(
        end_of_utterance_silence_trigger=0.6
    )
)

@client.on(ServerMessageType.END_OF_UTTERANCE)
def handle_turn(message):
    # Track which speaker finished
    if current_utterance:
        utterance = " ".join(current_utterance)
        # Note: speaker info available in result.alternatives[0].speaker
        print(f"Turn detected: {utterance}")
        current_utterance.clear()
```

### Timeout Handling

```python
import asyncio

# Set maximum utterance duration
MAX_UTTERANCE_TIME = 30  # 30 seconds

async def monitor_utterance_timeout():
    """Force end of utterance if too long."""
    await asyncio.sleep(MAX_UTTERANCE_TIME)
    await client.send_message({
        "message": ClientMessageType.FORCE_END_OF_UTTERANCE
    })
```

## Advanced Turn Detection

Want more sophisticated turn detection? Check out the **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** example which demonstrates:

- **ADAPTIVE mode** - Adjusts to speaker's speech patterns
- **SMART_TURN mode** - ML-based semantic turn prediction
- **EXTERNAL mode** - Manual turn control for custom workflows
- Preset configurations for common use cases

The Voice SDK provides a higher-level abstraction with intelligent segmentation and automatic turn detection.

## Next Steps

- **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** - Advanced turn detection modes
- **[Real-time Translation](../05-multilingual-translation/)** - Combine with translation

## Troubleshooting

### PyAudio Installation Issues

**Windows:**
```bash
pip install pipwin
pipwin install pyaudio
```

**Mac:**
```bash
brew install portaudio
pip install pyaudio
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install portaudio19-dev
pip install pyaudio
```

**"Turns detected too early"**
- Increase `end_of_utterance_silence_trigger` (try 0.8-1.2s)
- Consider your use case (dictation needs longer pauses)

**"Turns not detected"**
- Decrease `end_of_utterance_silence_trigger` (try 0.3-0.5s)
- Check microphone levels (speak clearly)
- Verify threshold is not set to 0 (which disables detection)

**"Authentication failed"**
- Check your API key in the `.env` file
- Verify your key at [portal.speechmatics.com](https://portal.speechmatics.com/)

## Resources

- [Turn Detection Docs](https://docs.speechmatics.com/speech-to-text/realtime/turn-detection)
- [Realtime API Guide](https://docs.speechmatics.com/introduction/realtime-guide)
- [WebSocket API Reference](https://docs.speechmatics.com/rt-api-ref)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Real-time

[Back to Basics](../) | [Back to Academy](../../README.md)

