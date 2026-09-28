<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/LK_wordmark_darkbg.png">
  <source media="(prefers-color-scheme: light)" srcset="../logo/LK_wordmark_lightbg.png">
  <img alt="LiveKit" src="../logo/LK_wordmark_lightbg.png" width="300">
</picture>

# Simple Voice Assistant - LiveKit + Speechmatics

**Build a conversational voice assistant using LiveKit Agents with Speechmatics speech recognition.**

</div>

A complete voice assistant using LiveKit's real-time WebRTC infrastructure with best-in-class speech recognition (Speechmatics), natural language processing (OpenAI), and text-to-speech (ElevenLabs).

## What You'll Learn

- How to integrate Speechmatics STT with LiveKit Agents
- Building a complete voice assistant with WebRTC
- Using LiveKit's agent framework for real-time conversations
- VAD-driven turn detection — the STT finalizes each turn from the shared Silero VAD
- Voice Activity Detection (VAD) for natural turn-taking
- Labeling speakers in the transcript using diarization
- **Speaker identification** — enroll and recognize returning users by name across sessions

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **OpenAI API Key**: Get one from [platform.openai.com](https://platform.openai.com/)
- **ElevenLabs API Key**: Get one from [elevenlabs.io](https://elevenlabs.io/)
- **LiveKit Cloud Account**: Get one from [cloud.livekit.io](https://cloud.livekit.io/)
- **Python 3.10+**

## Quick Start

> [!TIP]
> **Using a remote VM?** Console mode requires local microphone access. If you're running on a remote server, use `python main.py dev` and connect via the [LiveKit Agents Playground](https://agents-playground.livekit.io) instead. See [Testing with the Agents Playground](#testing-with-the-agents-playground) for details.

### Python

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API keys**

<details>
<summary><strong>Option A: Using LiveKit CLI (Recommended)</strong></summary>

The [LiveKit CLI](https://docs.livekit.io/home/cli/) simplifies credential management:

**Install the CLI:**
```bash
# macOS
brew install livekit-cli

# Windows
winget install LiveKit.LiveKitCLI

# Linux
curl -sSL https://get.livekit.io/cli | bash
```

**Authenticate and load credentials:**
```bash
lk cloud auth        # Opens browser to authenticate with LiveKit Cloud
lk app env -w        # Writes LiveKit credentials to .env.local
```

Then add your other API keys to `.env.local`:
```
SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
ELEVEN_API_KEY=your_elevenlabs_api_key_here
```

</details>

<details open>
<summary><strong>Option B: Manual Configuration</strong></summary>

```bash
cp ../.env.example ../.env
```

Open the `.env` file (in the project root, one level up from `python/`) and add your API keys:

```
SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
ELEVEN_API_KEY=your_elevenlabs_api_key_here
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key_here
LIVEKIT_API_SECRET=your_livekit_api_secret_here
```

</details>

> [!NOTE]
> LiveKit's ElevenLabs plugin uses `ELEVEN_API_KEY` (not `ELEVENLABS_API_KEY`).

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Run the agent**

For local development with console mode:
```bash
python main.py console
```

For development server (connects to LiveKit Cloud):
```bash
python main.py dev
```

## Architecture

```mermaid
flowchart LR
    subgraph Client
        USER[User Browser/App]
    end

    subgraph LiveKit Cloud
        ROOM[LiveKit Room]
    end

    subgraph Agent
        STT[Speechmatics STT]
        LLM[OpenAI LLM]
        TTS[ElevenLabs TTS]
        VAD[Silero VAD]
    end

    USER <-->|WebRTC| ROOM
    ROOM --> STT
    STT --> LLM
    LLM --> TTS
    TTS --> ROOM
    VAD --> STT
```

## How It Works

### Pipeline Components

1. **LiveKit Room** - WebRTC connection for real-time audio/video
2. **Speechmatics STT** - Transcribes speech to text with diarization
3. **OpenAI LLM** - Generates intelligent responses
4. **ElevenLabs TTS** - Converts text responses to natural speech
5. **Silero VAD** - Voice Activity Detection for turn-taking

### Key Features

| Feature | Description |
|---------|-------------|
| **WebRTC** | Real-time audio streaming via LiveKit infrastructure |
| **Turn Detection** | VAD-driven finalization — the STT ends each turn from the shared Silero VAD |
| **Diarization** | Speaker identification to distinguish different speakers |
| **VAD** | Silero Voice Activity Detection for natural turn-taking |
| **Auto Greeting** | Agent greets user when session starts |
| **Speaker Identification** | Enroll and recognize returning users by voiceprint across sessions |
| **Cloud Ready** | Deploy to LiveKit Cloud for production |

### Speaker Identification

The assistant automatically captures voiceprints during conversation and saves them to `speakers.json`. On subsequent sessions, returning speakers are recognized by name.

**How enrollment works:**

1. **First session** — speakers are labeled generically (`S1`, `S2`) by diarization
2. **Background capture** — voiceprints are automatically captured via `GET_SPEAKERS` every 30 seconds and saved to `speakers.json`
3. **Assign a name** — edit `"label": "S1"` to `"label": "Edgar"` (or any name) in `speakers.json`
4. **Next session** — the saved voiceprint is loaded as a `known_speaker` and Speechmatics recognizes the returning user by name

**`speakers.json` format:**
```json
[
  {
    "label": "Edgar",
    "speaker_identifiers": ["<voiceprint-hash>"]
  }
]
```

### Code Highlights

```python
from livekit.agents import AgentSession, Agent
from livekit.plugins import speechmatics, openai, elevenlabs, silero
from livekit.plugins.speechmatics import SpeakerIdentifier

# Load previously enrolled speakers from speakers.json
known_speakers = load_known_speakers()  # returns list[SpeakerIdentifier]

async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()

    # The same Silero VAD drives both the session and the STT's turn finalization.
    # Passing `vad` into the STT forces EXTERNAL turn detection — no manual finalize() glue.
    vad = silero.VAD.load()

    stt = speechmatics.STT(
        vad=vad,
        enable_diarization=True,
        speaker_format="<{speaker_id}>{text}</{speaker_id}>",
        known_speakers=known_speakers,  # Recognize returning users
    )

    session = AgentSession(
        stt=stt,
        llm=openai.LLM(model="gpt-4o-mini"),
        tts=elevenlabs.TTS(voice_id="21m00Tcm4TlvDq8ikWAM"),
        vad=vad,
    )

    await session.start(room=ctx.room, agent=VoiceAssistant())

    # Capture voiceprints in background and save to speakers.json
    async def capture_voiceprints():
        await asyncio.sleep(15)
        while True:
            result = await stt.get_speaker_ids()
            if result:
                save_speakers(result)
            await asyncio.sleep(30)

    asyncio.create_task(capture_voiceprints())
```

## Expected Output

```
INFO     | Starting agent...
INFO     | Connected to LiveKit room

Roxie: "Hey there! Roxie here, ready to make you laugh. What's on your mind?"

You: "Tell me a joke"
Roxie: "So I told my wife she was drawing her eyebrows too high... She looked surprised!"

You: "That's terrible"
Roxie: "Um... yeah, I know. But you still laughed a little, didn't you?"
```

## Customization

### Change the Voice

Edit the `voice_id` parameter in `main.py`:

```python
tts = elevenlabs.TTS(
    voice_id="your_voice_id_here",  # Find voices at elevenlabs.io
)
```

### Customize the Agent Prompt

Edit `assets/agent.md` to change the assistant's personality and capabilities. The default prompt configures Roxie as a standup comedian with:

- Witty banter and snappy responses
- Natural hesitations (um, uh) for realistic speech
- Multi-speaker awareness (active listener in group conversations)
- Spoken format optimizations (no emojis, numbers as words, expanded acronyms)

### Speaker Diarization

The STT is configured to label each speaker in the transcript:

```python
stt = speechmatics.STT(
    enable_diarization=True,
    speaker_format="<{speaker_id}>{text}</{speaker_id}>",
)
```

| Parameter | Purpose |
|-----------|---------|
| `enable_diarization` | Identify different speakers in the audio |
| `speaker_format` | Template for embedding the speaker label in the transcript, e.g. `<S1>Hello</S1>` |

**How it works:**
1. Diarization assigns each speaker a label (`S1`, `S2`, ...) based on their voice
2. `speaker_format` wraps each transcript segment with its speaker's tag before it reaches the LLM
3. The agent prompt (`assets/agent.md`) tells the LLM how to interpret the tags, so it can follow who said what in multi-speaker conversations

### Turn Detection

This example lets the **Silero VAD drive turn finalization**. The same `vad` passed to the
`AgentSession` is also passed to `speechmatics.STT(...)`, so the plugin finalizes each turn on
end-of-speech with no manual `finalize()` glue. Passing `vad` forces `EXTERNAL` turn detection
(the plugin auto-loads Silero if you set `EXTERNAL` and pass no `vad`):

```python
vad = silero.VAD.load()
stt = speechmatics.STT(vad=vad)  # STT finalizes turns from the VAD
```

Alternatively, omit `vad` on the STT and let the service run its own VAD by setting
`turn_detection_mode=TurnDetectionMode.VAD`:

```python
from livekit.plugins.speechmatics import TurnDetectionMode

stt = speechmatics.STT(
    turn_detection_mode=TurnDetectionMode.VAD,
)
```

| Mode | Description |
|------|-------------|
| `EXTERNAL` | Default. Turn boundaries are controlled by the caller — an external VAD (e.g. the shared Silero instance) drives `finalize()` |
| `VAD` | The STT service runs its own VAD and closes turns itself, no client-side VAD needed |

Older mode names (`SMART_TURN`, `ADAPTIVE`, `FIXED`) still work but now behave identically to `EXTERNAL`, and are scheduled for removal after 2026-10-05.

## Running Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Console** | `python main.py console` | Local testing with microphone |
| **Dev** | `python main.py dev` | Connects to LiveKit Cloud for testing |
| **Production** | `python main.py start` | Production deployment |

## Testing with the Agents Playground

The [LiveKit Agents Playground](https://agents-playground.livekit.io) is a web-based interface for testing your voice assistant without building a custom frontend.

**Step 1: Start your agent in dev mode**

```bash
python main.py dev
```

**Step 2: Open the Agents Playground**

Visit [agents-playground.livekit.io](https://agents-playground.livekit.io) in your browser.

**Step 3: Connect to your LiveKit Cloud project**

1. Click **Connect** and sign in with your LiveKit Cloud account
2. Select your project from the dropdown
3. The playground will automatically connect to your running agent

**Step 4: Start talking**

- Click the microphone button to enable audio
- Speak to Roxie and see real-time transcription
- The playground supports audio, video, and text input

> [!TIP]
> The playground shows live transcription, audio visualization, and agent responses - perfect for debugging speaker diarization.

## Troubleshooting

**Exception on Ctrl+C (Windows)**
- You may see a `KeyboardInterrupt` exception from the threading module when stopping the agent
- This is a cosmetic issue in the LiveKit Agents CLI on Windows
- The agent stops correctly despite the error message

**Error: "Invalid API key"**
- Verify all API keys in your `.env` file
- Check each service's portal for key validity

**Agent doesn't connect**
- Check `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`
- Verify your LiveKit Cloud project is active

**No audio input detected**
- Check your microphone permissions in the browser
- Ensure the LiveKit room is properly connected

**Agent doesn't respond**
- Check OpenAI API key is valid
- Verify you have API credits available

## Next Steps

- **[Voice Agent Turn Detection](../../../basics/08-voice-agent-turn-detection/)** - Learn about turn detection presets
- **[Voice Agent Speaker ID](../../../basics/09-voice-agent-speaker-id/)** - Speaker identification with the Voice SDK directly

## Resources

- [LiveKit Agents Documentation](https://docs.livekit.io/agents/)
- [LiveKit Speechmatics Plugin](https://docs.livekit.io/agents/models/stt/plugins/speechmatics/)
- [Speechmatics API Docs](https://docs.speechmatics.com/)
- [ElevenLabs API Docs](https://elevenlabs.io/docs)
- [OpenAI API Docs](https://platform.openai.com/docs)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**Integration**: LiveKit Agents

[Back to Integrations](../../) | [Back to Academy](../../../README.md)
