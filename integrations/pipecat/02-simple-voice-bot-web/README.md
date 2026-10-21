<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/pipecat.png">
  <source media="(prefers-color-scheme: light)" srcset="../logo/pipecat.png">
  <img alt="Pipecat" src="../logo/pipecat.png" width="300">
</picture>

# Simple Voice Bot (Web) - Pipecat + Speechmatics

**Build a browser-based conversational voice bot using Pipecat AI with Speechmatics speech recognition.**

</div>

Build a browser voice assistant with Pipecat and WebRTC. The pipeline uses Speechmatics Speech to Text (STT), a Groq-hosted large language model (LLM), and Cartesia Text to Speech (TTS). The Speechmatics adapter uses **agent STT**, powered by **Linden 1**, on the Realtime API.

Pipecat finalizes STT segments using external voice activity detection (VAD), then uses a local smart-turn analyzer to decide when to send the user turn to the LLM. Groq generates the response and Cartesia streams the synthesized audio.

> [!TIP]
> **Looking for local microphone version?** See [01-simple-voice-bot](../01-simple-voice-bot/) for a version that uses your local microphone and speakers directly.

## What You'll Learn

- How to integrate Speechmatics STT with Pipecat AI
- Building a browser-based voice assistant with WebRTC
- Using the Pipecat runner framework for web deployment
- Turn detection modes for natural conversations
- Tagging speakers in the transcript using speaker diarization
- Running a low-latency WebRTC pipeline with the Pipecat runner
- Measuring latency per component (STT / LLM / TTS) in the browser

## Prerequisites

- **Speechmatics API key**: Create one in the [Speechmatics portal](https://portal.speechmatics.com/)
- **Groq API key**: Get one from [console.groq.com](https://console.groq.com/)
- **Cartesia API key**: Get one from [cartesia.ai](https://cartesia.ai/)
- **Python 3.12 recommended**. The checked-in `pyproject.toml` declares `>=3.12,<=3.13`, which excludes Python 3.13 patch releases after 3.13.0; use 3.12 for the `uv` instructions below
- **macOS, Linux, or WSL2** (Windows native not supported for WebRTC)

## Quick Start

> [!NOTE]
> WebRTC transport requires macOS or Linux. **Windows users**: Use WSL2 (see [Windows WSL2 Setup](#windows-wsl2-setup) below).

### macOS/Linux

**Step 1: Create and activate a virtual environment**

```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**Step 3: Configure your API keys**

```bash
cp ../.env.example .env
```

Open the `.env` file and add your API keys:

```
SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
GROQ_API_KEY=your_groq_api_key_here
CARTESIA_API_KEY=your_cartesia_api_key_here
SPEECHMATICS_RT_URL=wss://eu2.rt.speechmatics.com/v2/agent
```

`SPEECHMATICS_RT_URL` selects the agent STT endpoint. The adapter defaults to the EU endpoint. To use the US endpoint:

```dotenv
SPEECHMATICS_RT_URL=wss://us.rt.speechmatics.com/v2/agent
```

The SDK also accepts a base URL ending in `/v2` and appends `/agent`. Choose an available region appropriate for your application's latency and data-location requirements.

**Step 4: Run the bot**

```bash
python main.py
```

**Step 5: Connect via browser**

Open [http://localhost:7860/client](http://localhost:7860/client) and click **Connect**.

To inspect performance, open the **Metrics** tab in the UI to see per-component timings (e.g. STT and LLM TTFB, TTS processing/TTFB).

### Windows WSL2 Setup

WebRTC dependencies don't work on Windows native. Use WSL2:

**Step 1: Install WSL2 (if not already)**

```powershell
wsl --install
```

**Step 2: Set up in WSL2**

<details>
<summary><strong>Option A: Using uv (Recommended)</strong></summary>

```bash
# Copy example to WSL native filesystem (avoids path issues)
# Replace YOUR_PATH with your actual Windows path to speechmatics-academy
mkdir -p ~/projects
cp -r /mnt/c/YOUR_PATH/integrations/pipecat/02-simple-voice-bot-web ~/projects/
cd ~/projects/02-simple-voice-bot-web

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Sync dependencies (uses pyproject.toml)
uv sync --python 3.12

# Copy and configure your .env file
cp .env.example .env
nano .env  # Add your API keys, then Ctrl+O to save, Ctrl+X to exit

# Run
uv run python python/main.py
```

</details>

<details>
<summary><strong>Option B: Using pip</strong></summary>

```bash
# Copy example to WSL native filesystem (avoids path issues)
# Replace YOUR_PATH with your actual Windows path to speechmatics-academy
mkdir -p ~/projects
cp -r /mnt/c/YOUR_PATH/integrations/pipecat/02-simple-voice-bot-web ~/projects/
cd ~/projects/02-simple-voice-bot-web/python

# Create venv and install deps
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Copy and configure your .env file
cp ../.env.example .env
nano .env  # Add your API keys, then Ctrl+O to save, Ctrl+X to exit

# Run
python main.py
```

</details>

**Step 3: Connect via browser**

Open [http://localhost:7860/client](http://localhost:7860/client) in your Windows browser and click **Connect**.

## Architecture

```mermaid
flowchart LR
    subgraph Browser
        CLIENT[Web Client]
    end

    subgraph Server
        WEBRTC[WebRTC Transport]
        STT[Speechmatics STT<br/>EXTERNAL mode]
        VAD[Silero VAD]
        UA[User Aggregator]
        AA[Assistant Aggregator]
        LLM[Groq LLM]
        TTS[Cartesia TTS]
    end

    CLIENT <-->|WebRTC| WEBRTC
    WEBRTC --> STT
    WEBRTC --> VAD
    STT --> UA
    UA --> LLM
    LLM --> TTS
    TTS --> WEBRTC
    TTS --> AA
```

## How It Works

### Pipeline Components

1. **WebRTC Transport** - Handles browser audio via WebRTC peer connection
2. **Speechmatics STT** - Transcribes speech to text in real-time with diarization and turn detection
3. **User Aggregator** - Builds conversation context for the LLM
4. **Groq LLM** - Generates intelligent responses
5. **Cartesia TTS** - Converts text responses to natural speech
6. **Assistant Aggregator** - Tracks assistant responses for context

### Key Features

| Feature | Description |
|---------|-------------|
| **Browser-Based** | Works from any browser - no local audio setup needed |
| **WebRTC** | Low-latency peer-to-peer audio streaming |
| **EXTERNAL Turn Detection** | Pipecat handles turn detection using external VAD (e.g., Silero) |
| **Diarization** | Labels distinct speakers in transcript segments |
| **Auto Greeting** | Bot greets user when connection is established |

### Code Highlights

```python
# Speechmatics STT with EXTERNAL turn detection and diarization
stt = SpeechmaticsSTTService(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    settings=SpeechmaticsSTTService.Settings(
        turn_detection_mode=SpeechmaticsSTTService.TurnDetectionMode.EXTERNAL,
        enable_diarization=True,
        # Agent STT tags one speaker per segment: <S1>Hello</S1>
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
    ),
)

# The aggregator runs VAD and broadcasts speech-stop events back to STT.
context = LLMContext(messages)
user_aggregator, assistant_aggregator = LLMContextAggregatorPair(
    context,
    user_params=LLMUserAggregatorParams(
        vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
        user_turn_strategies=UserTurnStrategies(
            stop=[TurnAnalyzerUserTurnStopStrategy(
                turn_analyzer=LocalSmartTurnAnalyzerV3()
            )]
        ),
    ),
)

# Transport handles audio; VAD is configured on the aggregator above.
transport_params = {
    "webrtc": lambda: TransportParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
    ),
}

pipeline = Pipeline([
    transport.input(),
    stt,
    user_aggregator,
    llm,
    tts,
    transport.output(),
    assistant_aggregator,
])
```

See `python/main.py` for the imports and complete setup.

## Expected Output

```
INFO     | Loading pipeline components...
INFO     | All components loaded!
INFO     | Started server process
INFO     | Uvicorn running on http://0.0.0.0:7860

# After clicking Connect in browser:
INFO     | Client connected
INFO     | Starting bot

Roxie: "Hey there! Roxie here, ready to make you laugh. What's on your mind?"

You: "Tell me a joke"
Roxie: "So I told my wife she was drawing her eyebrows too high... She looked surprised!"
```

## Measuring Latency

After connecting in the browser, open the **Metrics** tab in the web UI.

Use it to inspect per-component timings and validate latency improvements:

- **Speech to Text (Speechmatics)**
- **LLM (Groq)**
- **Text to Speech (Cartesia)**

## Customization

### Change the Voice

Edit the `voice_id` in `main.py`:

```python
tts = CartesiaTTSService(
    api_key=os.getenv("CARTESIA_API_KEY"),
    voice_id="your_voice_id_here",
)
```

### Customize the Agent Prompt

Edit `assets/agent.md` to change the bot's personality and capabilities. The default prompt configures Roxie as a standup comedian with:

- Witty banter and snappy responses
- Natural hesitations (um, uh) for realistic speech
- Multi-speaker awareness (active listener in group conversations)
- Spoken format optimizations (no emojis, numbers as words, expanded acronyms)

### Turn detection modes

The pinned Pipecat adapter exposes two modes:

| Mode | Who closes the STT turn? |
|------|-------------------------|
| `EXTERNAL` | The application calls `finalize()`; in this example the aggregator's VAD broadcasts `VADUserStoppedSpeakingFrame` to the STT service |
| `VAD` | The Speechmatics service detects the end of speech and emits turn events |

```python
stt = SpeechmaticsSTTService(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    settings=SpeechmaticsSTTService.Settings(
        turn_detection_mode=SpeechmaticsSTTService.TurnDetectionMode.EXTERNAL,
    ),
)
```

The running example combines `EXTERNAL` mode with `LLMUserAggregatorParams.vad_analyzer` and a local smart-turn stop strategy. Keep these roles separate: VAD finalizes STT output; the smart-turn strategy controls when the aggregated user turn reaches the LLM. `ADAPTIVE` and `SMART_TURN` are not members of the current Speechmatics adapter enum. See the [Pipecat Speechmatics guide](https://docs.pipecat.ai/server/services/stt/speechmatics) before changing the pipeline to service-driven `VAD` mode.

### Speaker diarization

The STT separates the transcript into speakers and tags each segment:

```python
stt = SpeechmaticsSTTService(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    settings=SpeechmaticsSTTService.Settings(
        turn_detection_mode=SpeechmaticsSTTService.TurnDetectionMode.EXTERNAL,
        enable_diarization=True,
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
    ),
)
```

| Parameter | Purpose |
|-----------|---------|
| `enable_diarization` | Separate the transcript into distinct speakers |
| `speaker_active_format` | Format applied to each speaker's segment: `<S1>Hello</S1>` |

## Troubleshooting

**Nothing happens after clicking Connect**
- Wait a few seconds for services to initialize
- Check the terminal for any error messages about API keys
- Try refreshing the browser and connecting again

**Error: "No module named 'pipecat_ai_small_webrtc_prebuilt'"**
```bash
pip install pipecat-ai-small-webrtc-prebuilt
```

**Error: "Invalid API key"**
- Verify all API keys in your `.env` file
- Check each service's portal for key validity

**No audio in browser**
- Check browser microphone permissions
- Ensure no other application is using the microphone

### WSL2-Specific Issues

**Error: "ensurepip is not available"**

Install the Python venv package:
```bash
sudo apt update && sudo apt install python3.12-venv -y
```

**Forgot WSL sudo password**

Open PowerShell (not WSL) and run:
```powershell
wsl -u root
passwd your_username
exit
```

**Error: "bad marshal data" or "marshal data too short"**

Python bytecode corruption. Clear cache and recreate venv:
```bash
deactivate
rm -rf .venv ~/.cache/pip
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

**.env file is read-only / write-protected**

Files copied from Windows are read-only. Create a new one:
```bash
rm .env
cat > .env << 'EOF'
SPEECHMATICS_API_KEY=your_key_here
GROQ_API_KEY=your_key_here
CARTESIA_API_KEY=your_key_here
EOF
```

**General WSL2 tip**: Always work in native WSL filesystem (`~/`) not Windows mounts (`/mnt/c/`)

## Next Steps

- **[Simple Voice Bot (Local)](../01-simple-voice-bot/)** - Local microphone version
- **[Agent STT](../../../basics/13-agent-stt/)** - Use the current Speechmatics SDK directly
- **[Speaker identification with the legacy Voice SDK](../../../basics/09-voice-agent-speaker-id/)** - Compare the earlier SDK approach

## Resources

- [Pipecat AI Documentation](https://docs.pipecat.ai/)
- [Pipecat SmallWebRTC Transport](https://docs.pipecat.ai/server/services/transport/small-webrtc)
- [Speechmatics Pipecat Integration](https://docs.pipecat.ai/server/services/stt/speechmatics)
- [Speechmatics API Docs](https://docs.speechmatics.com/)
- [Groq API Docs](https://console.groq.com/docs)
- [Cartesia API Docs](https://docs.cartesia.ai/)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Intermediate
**API Mode**: Realtime — agent STT
**Integration**: Pipecat AI (WebRTC)

[Back to Integrations](../../) | [Back to Academy](../../../README.md)
