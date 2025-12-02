# Voice Agent Speaker ID & Speaker Focus

**Speaker identification and focus control using Speechmatics Voice SDK.**

Learn how to extract speaker voice IDs for reuse across sessions and control which speakers drive your voice agent conversations.

## What You'll Learn

- Extracting speaker voice identifiers for persistent identification
- Speaker focus configuration (IGNORE vs RETAIN modes)
- Controlling which speakers can trigger conversation flow

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+** (Voice SDK requires 3.9+)
- **Microphone**: Built-in or external microphone
- **PyAudio**: For microphone access (installation instructions below)

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
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run the example**

```bash
python main.py
```

Select an example from the menu to explore speaker management features.

## How It Works

> [!NOTE]
> This example demonstrates two key speaker management features:
>
> 1. **Speaker ID Extraction** - Request speaker identifiers from the server for reuse across sessions
> 2. **Speaker Focus** - Control which speakers can drive conversation flow (IGNORE or RETAIN modes)

## Available Examples

| Example | Feature | Description |
|---------|---------|-------------|
| **1. Extract Speaker ID** | `GET_SPEAKERS` message | Get speaker identifiers for persistence |
| **2. Speaker Focus (IGNORE)** | `SpeakerFocusMode.IGNORE` | Only transcribe focused speaker |
| **3. Speaker Focus (RETAIN)** | `SpeakerFocusMode.RETAIN` | Focus on one, keep others as passive |

## Code Walkthrough

### 1. Extract Speaker IDs

Request speaker identifiers for later reuse:

```python
from speechmatics.rt import ClientMessageType
from speechmatics.voice import SpeakerIdentifier, VoiceAgentClient, VoiceAgentConfig

extracted_speakers = []

client = VoiceAgentClient(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    config=VoiceAgentConfig(
        language="en",
        enable_diarization=True,  # Required for speaker identification
    ),
)

@client.on(AgentServerMessageType.SPEAKERS_RESULT)
def on_speakers_result(message):
    for speaker in message.get("speakers", []):
        label = speaker.get("label")
        identifiers = speaker.get("speaker_identifiers", [])

        if label and identifiers:
            extracted_speakers.append(
                SpeakerIdentifier(
                    label=label,
                    speaker_identifiers=identifiers,
                )
            )
            print(f"Extracted Voice ID for {label}")

# Request speaker IDs after some speech
await client.send_message({"message": ClientMessageType.GET_SPEAKERS})
```

> [!TIP]
> Speaker identifiers are acoustic fingerprints. Save them to a database or file to recognize the same speaker in future sessions.

### 2. Speaker Focus Configuration

Control which speakers drive the conversation:

```python
from speechmatics.voice import SpeakerFocusConfig, SpeakerFocusMode, SpeakerIdentifier

# Use extracted speaker IDs with custom labels
known_speakers = [
    SpeakerIdentifier(
        label="User",
        speaker_identifiers=extracted_speakers[0].speaker_identifiers,
    ),
    SpeakerIdentifier(
        label="__BACKGROUND__",  # Auto-ignored by SDK
        speaker_identifiers=other_speaker_ids,
    ),
]

# Focus on user, ignore other speakers
client = VoiceAgentClient(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    config=VoiceAgentConfig(
        language="en",
        enable_diarization=True,
        known_speakers=known_speakers,
        speaker_config=SpeakerFocusConfig(
            focus_speakers=["User"],        # Primary speaker(s)
            focus_mode=SpeakerFocusMode.IGNORE,  # or RETAIN
        ),
    ),
)
```

## Speaker Focus Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| **IGNORE** | Non-focused speakers are completely excluded from output | Voice assistants (ignore TTS playback) |
| **RETAIN** | Non-focused speakers wrapped in `<PASSIVE>` tags, only alongside focused speaker | Multi-party meetings (track but prioritize one) |

> [!IMPORTANT]
> Only focused speakers can "drive" the conversation. Their speech triggers:
> - VAD (Voice Activity Detection) events
> - Turn detection and segment finalization
> - End-of-turn signals
>
> Non-focused speakers' words are processed but only emitted alongside active focused speaker content.

## Auto-Ignored Speakers

By default, any speaker label wrapped in double underscores is automatically ignored:

- `__ASSISTANT__` - Common pattern for AI assistant voice
- `__BOT__` - Alternative naming
- `__AGENT__` - Another alternative

This prevents the assistant's TTS output from being transcribed back (feedback loop prevention).

> [!IMPORTANT]
> **Speaker identifiers are still required.** The auto-ignore only works when Speechmatics can identify the speaker AS `__ASSISTANT__`. You must first capture the assistant's voice and extract its speaker identifiers, then register them in `known_speakers` with a `__NAME__` label. Without speaker identifiers, the voice will just be labeled as `S1`, `S2`, etc.

## Expected Output

### Example 1: Extract Speaker ID

```
============================================================
EXTRACT SPEAKER ID
============================================================
Enter your name: Edgar

Speak to extract voice identifier for 'Edgar'.
IDs will be saved after your first turn. Press Ctrl+C to exit.

<S1>Testing voice identification feature.</S1>
[END OF TURN]

Requesting speaker IDs...
Saved to assets/speakers.json
  Edgar: 1 identifiers
```

> [!NOTE]
> The session automatically exits after speaker IDs are saved to the `assets/` folder.

### Example 2: Speaker Focus (IGNORE)

```
============================================================
SPEAKER FOCUS (IGNORE MODE)
============================================================
Loaded 1 speaker(s) from assets/speakers.json
Focusing on: Edgar
Other speakers will be completely ignored. Press Ctrl+C to exit.

<Edgar>Only my speech appears in the transcript.</Edgar>
[END OF TURN]
```

### Example 3: Speaker Focus (RETAIN)

```
============================================================
SPEAKER FOCUS (RETAIN MODE)
============================================================
Loaded 1 speaker(s) from assets/speakers.json
Focusing on: Edgar
Other speakers will appear wrapped in <PASSIVE> tags. Press Ctrl+C to exit.

<Edgar>I'm the primary speaker.</Edgar>
[END OF TURN]

<Edgar>Here's what I'm saying.</Edgar>
<PASSIVE><S1>And here's what they said.</S1></PASSIVE>
[END OF TURN]
```

## Key Features Demonstrated

**Speaker ID Extraction:**
- Request speaker identifiers via `GET_SPEAKERS` message
- Acoustic fingerprints for speaker recognition
- Persistent identification across sessions
- Reuse extracted IDs with custom labels

**Speaker Focus:**
- Designate primary speakers who drive conversation
- IGNORE mode for complete exclusion of non-focused speakers
- RETAIN mode for passive speaker tracking alongside focused speaker
- Auto-ignore pattern for assistant voices (`__NAME__`)

## Use Cases

### Voice Assistant
```python
# Focus on user, ignore assistant TTS playback
config = VoiceAgentConfig(
    enable_diarization=True,
    known_speakers=[
        SpeakerIdentifier(label="__ASSISTANT__", speaker_identifiers=[...]),
        SpeakerIdentifier(label="User", speaker_identifiers=[...]),
    ],
    speaker_config=SpeakerFocusConfig(
        focus_speakers=["User"],
        focus_mode=SpeakerFocusMode.IGNORE,
    ),
)
```

### Meeting Transcription
```python
# Track all speakers with custom names
config = VoiceAgentConfig(
    enable_diarization=True,
    known_speakers=[
        SpeakerIdentifier(label="Alice", speaker_identifiers=[...]),
        SpeakerIdentifier(label="Bob", speaker_identifiers=[...]),
        SpeakerIdentifier(label="Charlie", speaker_identifiers=[...]),
    ],
)
```

### Customer Support
```python
# Focus on customer, retain agent as passive
config = VoiceAgentConfig(
    enable_diarization=True,
    known_speakers=[
        SpeakerIdentifier(label="Agent", speaker_identifiers=[...]),
        SpeakerIdentifier(label="Customer", speaker_identifiers=[...]),
    ],
    speaker_config=SpeakerFocusConfig(
        focus_speakers=["Customer"],
        focus_mode=SpeakerFocusMode.RETAIN,
    ),
)
```

## Next Steps

- **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** - Advanced turn detection modes
- **[Configuration Guide](../03-configuration-guide/)** - All configuration options
- **[Real-time Translation](../05-multilingual-translation/)** - Add translation support

## Troubleshooting

**PyAudio Installation Issues**

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

**"No speaker identifiers received"**
- Ensure enough speech was captured (at least 5-10 seconds)
- Check that diarization is enabled
- Verify API key has access to speaker identification features

**"Speaker labels not matching"**
- Speaker identifiers are acoustic-based; similar voices may be grouped
- Use multiple identifier strings per speaker for better matching
- Consider environmental factors (background noise, microphone quality)

**"Authentication failed" error**
- Verify API key in `.env` file
- Check your key at [portal.speechmatics.com](https://portal.speechmatics.com/)
- Ensure no extra spaces in `.env` file

## Resources

- [Voice SDK Documentation](https://docs.speechmatics.com/voice-agent-sdk)
- [Speaker Diarization Guide](https://docs.speechmatics.com/speech-to-text/features/diarization)
- [Real-time API Reference](https://docs.speechmatics.com/api-ref/realtime-transcription-websocket)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Voice Agent (Real-time)
**Languages**: Python

[Back to Basics](../) | [Back to Academy](../../README.md)
