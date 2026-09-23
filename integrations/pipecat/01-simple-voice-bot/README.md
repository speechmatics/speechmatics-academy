<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/pipecat.png">
  <source media="(prefers-color-scheme: light)" srcset="../logo/pipecat.png">
  <img alt="Pipecat" src="../logo/pipecat.png" width="300">
</picture>

# Simple Voice Bot - Pipecat + Speechmatics

**Build a conversational voice bot using Pipecat AI with Speechmatics speech recognition.**

</div>

A complete voice assistant pipeline combining best-in-class speech recognition (Speechmatics), natural language processing (OpenAI), and text-to-speech (ElevenLabs) using the Pipecat AI framework - all running locally with your microphone and speakers.

## What You'll Learn

- How to integrate Speechmatics STT with Pipecat AI
- Building a complete voice assistant pipeline
- Using local audio transport (no cloud infrastructure needed)
- Voice Activity Detection (VAD) for natural conversations
- Speaker diarization to label who is speaking in the transcript

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **OpenAI API Key**: Get one from [platform.openai.com](https://platform.openai.com/)
- **ElevenLabs API Key**: Get one from [elevenlabs.io](https://elevenlabs.io/)
- **Python 3.10+** (Python 3.12 recommended)
- **PortAudio**: Required for local audio (see installation below)

## Quick Start

> [!TIP]
> **Using a remote VM or Windows?** This example uses `LocalAudioTransport` which requires local microphone access. For browser-based testing, see [02-simple-voice-bot-web](../02-simple-voice-bot-web/) instead.

### Python

**Step 1: Install PortAudio (system dependency)**

**On Windows:**
```bash
# PortAudio is included with PyAudio wheel - no separate install needed
```

**On Mac:**
```bash
brew install portaudio
```

**On Linux (Ubuntu/Debian):**
```bash
sudo apt-get install portaudio19-dev
```

**Step 2: Create and activate a virtual environment**

> [!IMPORTANT]
> **macOS Users**: Pipecat requires Python 3.10+. Your system Python may be older (e.g., Python 3.9.6). You must use Python 3.10+ when creating the virtual environment.

**On Windows:**
```bash
cd python
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python

# First, check your Python version
python3 --version

# If Python is below 3.10, install Python 3.12 via Homebrew (macOS)
brew install python@3.12

# Create venv with Python 3.12 explicitly
python3.12 -m venv .venv
source .venv/bin/activate

# Verify the venv is using the correct Python
python --version  # Should show Python 3.12.x
```

**Step 3: Install dependencies**

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

> [!NOTE]
> **Dependency Conflicts**: If you see numpy/numba conflicts like `numba requires numpy<2.3`, fix with:
> ```bash
> pip install "numpy>=1.24,<2.3"
> ```

**Step 4: Configure your API keys**

```bash
cp ../.env.example .env
```

Open the `.env` file and add your API keys:

```
SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

> [!NOTE]
> **Missing `.env.example` after download?** If you downloaded the repo as a ZIP file, dotfiles (files starting with `.`) may not appear in Finder or may be excluded. Use `git clone` instead, or run `ls -la ..` in terminal to verify the file exists. See [Troubleshooting](#dotfiles-missing-after-zip-download) for more details.

**Step 5: Run the example**

```bash
python main.py
```

## Architecture

```mermaid
flowchart LR
    subgraph Input
        MIC[Local Microphone]
    end

    subgraph Processing
        STT[Speechmatics STT<br/>diarization]
        UA[User Aggregator]
        LLM[OpenAI LLM]
        AA[Assistant Aggregator]
    end

    subgraph Output
        TTS[ElevenLabs TTS]
        SPK[Local Speakers]
    end

    MIC --> VAD[Silero VAD<br/>signals turn end]
    VAD --> STT
    STT --> UA
    UA --> LLM
    LLM --> TTS
    TTS --> SPK
    TTS --> AA
```

## How It Works

### Pipeline Components

1. **Local Microphone** - Captures audio from your microphone via PyAudio
2. **Silero VAD Processor** - Detects when the user starts/stops speaking; emits `VADUserStoppedSpeakingFrame` so STT knows when to finalize the turn
3. **Speechmatics STT** - Transcribes speech to text in real-time (configured for `EXTERNAL` turn detection — finalization is driven by the VAD step above)
4. **User Aggregator** - Builds conversation context for the LLM
5. **OpenAI LLM** - Generates intelligent responses
6. **ElevenLabs TTS** - Converts text responses to natural speech
7. **Local Speakers** - Plays audio back through your speakers
8. **Assistant Aggregator** - Tracks assistant responses for context

### Key Features

| Feature | Description |
|---------|-------------|
| **Local Audio** | Uses your microphone and speakers directly - no WebRTC needed |
| **VAD** | Silero Voice Activity Detection for natural turn-taking |
| **Diarization** | Speaker identification labels each speaker (S1, S2, ...) in the transcript |
| **Interruptions** | User can interrupt the bot mid-response |

### Code Highlights

```python
# Local audio transport. In pipecat 1.x, VAD is no longer configured on the
# transport — it lives in a dedicated VADProcessor inserted into the pipeline.
transport = LocalAudioTransport(
    LocalAudioTransportParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
    )
)

# VAD processor: emits VADUserStoppedSpeakingFrame when the user stops talking.
# This is what drives end-of-utterance for the STT service in EXTERNAL mode.
vad_processor = VADProcessor(vad_analyzer=SileroVADAnalyzer())

# Speechmatics STT with diarization and speaker-labeled formatting.
# turn_detection_mode=EXTERNAL means finalization is driven by the VAD
# processor above, not a server-side silence timer.
stt = SpeechmaticsSTTService(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    settings=SpeechmaticsSTTService.Settings(
        turn_detection_mode=SpeechmaticsSTTService.TurnDetectionMode.EXTERNAL,
        enable_diarization=True,
        # Wraps each speaker's text in a tag the LLM can read, e.g. <S1>Hello</S1>
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
    ),
)

# Pipeline: mic -> VAD -> STT -> LLM -> TTS -> speakers
pipeline = Pipeline([
    transport.input(),
    vad_processor,
    stt,
    user_aggregator,
    llm,
    tts,
    transport.output(),
    assistant_aggregator,
])
```

## Expected Output

```
INFO     | Starting voice bot...
INFO     | The first voice heard is labelled S1, the next S2, and so on.
INFO     | Press Ctrl+C to exit.

You: "Hello there!"
Roxie: "Hey there! Roxie here, ready to make you laugh. What's on your mind?"

You: "Tell me a joke"
Roxie: "So I told my wife she was drawing her eyebrows too high... She looked surprised!"

You: "That's terrible"
Roxie: "Um... yeah, I know. But you still laughed a little, didn't you?"

^C
INFO     | Voice bot stopped.
```

## Customization

### Change the Voice

Edit the `voice` field in `main.py`:

```python
tts = ElevenLabsTTSService(
    aiohttp_session=session,
    api_key=os.getenv("ELEVENLABS_API_KEY"),
    settings=ElevenLabsTTSService.Settings(
        voice="your_voice_id_here",  # Find voices at elevenlabs.io
    ),
)
```

### Customize the Agent Prompt

Edit `assets/agent.md` to change the bot's personality and capabilities. The default prompt configures Roxie as a standup comedian with:

- Witty banter and snappy responses
- Natural hesitations (um, uh) for realistic speech
- Multi-speaker awareness (active listener in group conversations)
- Spoken format optimizations (no emojis, numbers as words, expanded acronyms)

### Speaker Diarization

The STT is configured to identify speakers and label them in the transcript:

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
| `enable_diarization` | Identify different speakers in the audio |
| `speaker_active_format` | Wraps each speaker's text in a tag, e.g. `<S1>Hello</S1>` |

**How it works:**
1. The first voice heard is labelled `S1`, the next distinct voice `S2`, and so on
2. Each transcript segment is wrapped in its speaker tag before being sent to the LLM
3. The agent prompt (`assets/agent.md`) is told how to interpret these tags, so in multi-speaker scenarios Roxie acts as an active listener and only joins when invited

### Adjust VAD Sensitivity

VAD parameters are passed to `SileroVADAnalyzer` and the analyzer is wrapped by
the `VADProcessor` in the pipeline:

```python
from pipecat.audio.vad.vad_analyzer import VADParams

vad_processor = VADProcessor(
    vad_analyzer=SileroVADAnalyzer(
        params=VADParams(
            min_volume=0.6,  # Lower = more sensitive to quiet speech
            stop_secs=0.2,   # How long of silence before "stopped speaking"
        )
    )
)
```

## Browser-Based Alternative

If you're on a remote VM, Windows, or prefer browser-based testing, see **[02-simple-voice-bot-web](../02-simple-voice-bot-web/)** - a WebRTC version that works from any browser.

## Troubleshooting

### macOS-Specific Issues

#### Wrong Python Version in Virtual Environment

**Symptom:** `pip install` shows errors like:
```
ERROR: Ignored the following versions that require a different python version: 0.0.37 Requires-Python >=3.10 ...
ERROR: No matching distribution found for pipecat-ai
```

**Cause:** Your virtual environment was created with Python 3.9 (macOS system Python), but Pipecat requires Python 3.10+.

**Fix:**
```bash
# Check your current Python version
python3 --version

# If below 3.10, install Python 3.12 via Homebrew
brew install python@3.12

# Recreate the virtual environment with Python 3.12
deactivate
rm -rf .venv
python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

#### NLTK SSL Certificate Error

**Symptom:**
```
[nltk_data] Error loading punkt_tab: <urlopen error [SSL:
[nltk_data]     CERTIFICATE_VERIFY_FAILED] certificate verify failed
```

**Fix:**
```bash
# Install certifi and download NLTK data with SSL workaround
pip install certifi
python3 -c "import ssl; ssl._create_default_https_context = ssl._create_unverified_context; import nltk; nltk.download('punkt_tab')"
```

#### Dotfiles Missing After ZIP Download

**Symptom:** `.env.example` is missing after downloading the repo as a ZIP from GitHub.

**Cause:** macOS Finder hides dotfiles by default, and some ZIP extraction methods may exclude them.

**Fix options:**

1. **Check if it's just hidden:**
   ```bash
   ls -la ..  # List all files including hidden ones
   ```

2. **Use `git clone` instead of ZIP download:**
   ```bash
   git clone https://github.com/speechmatics/speechmatics-academy.git
   ```

3. **Show hidden files in Finder:**
   ```bash
   defaults write com.apple.finder AppleShowAllFiles YES
   killall Finder
   ```

4. **Create the file manually** if truly missing:
   ```bash
   cat > .env << 'EOF'
   SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
   OPENAI_API_KEY=your_openai_api_key_here
   ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
   EOF
   ```

### General Issues

**Error: "No module named 'pyaudio'"**
- Install PortAudio first (see Step 1)
- On Windows, try: `pip install pipwin && pipwin install pyaudio`

**Error: "Invalid API key"**
- Verify all API keys in your `.env` file
- Check each service's portal for key validity

**Error: numpy/numba dependency conflict**

**Symptom:**
```
numba 0.61.2 requires numpy<2.3,>=1.24, but you have numpy 2.3.5 which is incompatible.
```

**Fix:**
```bash
pip install "numpy>=1.24,<2.3"
```

**No audio input detected**
- Check your microphone is selected as default input device
- Try lowering `min_volume` in `VADParams` (see [Adjust VAD Sensitivity](#adjust-vad-sensitivity))

**Bot doesn't respond**
- Check OpenAI API key is valid
- Verify you have API credits available

**Audio output issues**
- Check your speakers are selected as default output device
- Verify ElevenLabs API key and voice_id are correct

## Next Steps

- **[Simple Voice Bot (Web)](../02-simple-voice-bot-web/)** - Browser-based version with WebRTC
- **[Voice Agent Turn Detection](../../../basics/08-voice-agent-turn-detection/)** - Learn about turn detection presets
- **[Voice Agent Speaker ID](../../../basics/09-voice-agent-speaker-id/)** - Advanced speaker identification

## Resources

- [Pipecat AI Documentation](https://docs.pipecat.ai/)
- [Speechmatics Pipecat Integration](https://docs.pipecat.ai/server/services/stt/speechmatics)
- [Speechmatics API Docs](https://docs.speechmatics.com/)
- [ElevenLabs API Docs](https://elevenlabs.io/docs)
- [OpenAI API Docs](https://platform.openai.com/docs)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Intermediate
**Integration**: Pipecat AI

[Back to Integrations](../../) | [Back to Academy](../../../README.md)