# Voice Agent Turn Detection

**Real-time voice transcription with intelligent turn detection using Speechmatics Voice SDK presets.**

Learn how to use optimized preset configurations for different conversational AI use cases including voice assistants, note-taking, live captions, and multi-party conversations.

## What You'll Learn

- How to use official Voice SDK presets
- Different turn detection modes (FIXED, ADAPTIVE, SMART_TURN, EXTERNAL)
- How silence thresholds affect turn endings
- Sentence-based vs turn-based segmentation
- Real-time event handling with the Voice Agent client
- When to use each preset for optimal results

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

**Note**: The requirements include ML dependencies for SMART_TURN mode (certifi, onnxruntime, transformers).

**Step 3: Configure API key**

```bash
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run the example**

```bash
python main.py
```

Select a preset from the menu (or press Enter for default), then speak into your microphone!

## How It Works

This example demonstrates intelligent turn detection by:

1. **Loading preset configurations** - Uses official SDK presets optimized for different use cases
2. **Setting up Voice Agent Client** - Creates a client with the selected preset configuration
3. **Registering event handlers** - Listens for partial segments, final segments, and turn endings
4. **Streaming microphone audio** - Captures and sends audio in real-time
5. **Displaying results** - Shows live transcription with speaker identification
6. **Detecting turn endings** - Automatically identifies when the speaker has finished

### Available Presets

The Voice SDK includes 6 optimized presets:

| Preset | Mode | Use Case | Silence Trigger | Key Feature |
|--------|------|----------|-----------------|-------------|
| **low_latency** | FIXED | Real-time captions | 0.5s | Quick finalization |
| **conversation_adaptive** | ADAPTIVE | Voice assistants | 1.0s | Adapts to speech patterns |
| **conversation_smart_turn** | SMART_TURN | Interviews | 1.0s + ML | ML-based prediction |
| **scribe** | FIXED | Note-taking | 1.2s | Sentence-level segments |
| **captions** | FIXED | Live captioning | 1.2s | Consistent formatting |
| **external** | EXTERNAL | Push-to-talk | Manual | Custom control |

### Code Walkthrough

**1. Loading Presets**

```python
from speechmatics.voice import VoiceAgentConfigPreset

# Load preset from SDK (includes all optimized settings)
config = VoiceAgentConfigPreset.load("conversation_adaptive")

# Preset includes:
# - end_of_utterance_mode (ADAPTIVE)
# - silence_trigger (1.0s)
# - max_delay (0.7s)
# - operating_point (ENHANCED)
# - and more...
```

**2. Creating the Client**

```python
from speechmatics.voice import VoiceAgentClient

client = VoiceAgentClient(
    api_key=os.getenv("SPEECHMATICS_API_KEY"),
    config=config
)
```

**3. Event Handlers**

The example registers three event handlers:

**Partial Segments (real-time updates):**
```python
@client.on(AgentServerMessageType.ADD_PARTIAL_SEGMENT)
def on_partial(message):
    for segment in message.get("segments", []):
        print(f"\r> {segment['text']}", end="", flush=True)
```

**Final Segments (complete transcription):**
```python
@client.on(AgentServerMessageType.ADD_SEGMENT)
def on_final(message):
    for segment in message.get("segments", []):
        speaker = segment.get("speaker_id", "S1")
        text = segment["text"]
        print(f"\n[{speaker}]: {text}")
```

**Turn Endings (speaker finished):**
```python
@client.on(AgentServerMessageType.END_OF_TURN)
def on_turn_end(message):
    print("[END OF TURN]\n")
```

**4. Streaming Audio**

```python
from speechmatics.rt import Microphone

mic = Microphone(sample_rate=16000, chunk_size=320)
mic.start()

await client.connect()

while True:
    audio_chunk = await mic.read(320)
    await client.send_audio(audio_chunk)
```

**5. Error Handling**

```python
from speechmatics.rt import AuthenticationError

try:
    segments = await run_preset(preset_name)
except (AuthenticationError, ValueError) as e:
    print(f"\nAuthentication Error: {e}")
    if not os.getenv("SPEECHMATICS_API_KEY"):
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
```

## Expected Output

### Startup

```
Available Presets:
======================================================================
1. low_latency              - Quick finalization, best for real-time captions
2. conversation_adaptive    - Adapts to speech patterns, best for voice assistants
3. conversation_smart_turn  - ML-based turn detection for conversations
4. scribe                   - Optimized for note-taking and dictation
5. captions                 - Consistent formatting for live captioning
6. external                 - Manual turn control for custom logic
======================================================================

Select preset number (or press Enter for conversation_adaptive): 2
```

### Running - CONVERSATION_ADAPTIVE

```
======================================================================
PRESET: CONVERSATION_ADAPTIVE
======================================================================
Mode: adaptive
Operating Point: enhanced
Silence Trigger: 1.0s
Max Delay: 0.7s

Speak into your microphone. Press Ctrl+C to stop.
======================================================================

> Hello, I need help with my account
[S1]: Hello, I need help with my account.
[END OF TURN]

> I'm having trouble logging in and resetting my password
[S1]: I'm having trouble logging in and resetting my password.
[END OF TURN]

> Um, I tried the forgot password link but it's not sending me an email
[S1]: Um, I tried the forgot password link but it's not sending me an email.
[END OF TURN]

^C

Stopped. Captured 3 segments.

======================================================================
SUMMARY
======================================================================
1. [S1]: Hello, I need help with my account.
2. [S1]: I'm having trouble logging in and resetting my password.
3. [S1]: Um, I tried the forgot password link but it's not sending me an email.
```

### Running - SCRIBE (Sentence-Based)

```
======================================================================
PRESET: SCRIBE
======================================================================
Mode: fixed
Operating Point: enhanced
Silence Trigger: 1.2s
Max Delay: 1.0s

> Meeting notes for January 15th
[S1]: Meeting notes for January 15th.
> First agenda item is quarterly review
[S1]: First agenda item is quarterly review.
[END OF TURN]

> Revenue increased by 23%
[S1]: Revenue increased by 23%.
> Customer satisfaction scores improved
[S1]: Customer satisfaction scores improved.
[END OF TURN]
```

**Note:** SCRIBE emits **each sentence as a separate segment** before END_OF_TURN. This is designed for note-taking where you want sentence-level granularity.

## Key Features Demonstrated

**Turn Detection Modes:**
- **FIXED**: Consistent silence threshold across all speakers
- **ADAPTIVE**: Adjusts based on speech rate and pauses
- **SMART_TURN**: ML prediction of semantic turn boundaries
- **EXTERNAL**: Manual control via `client.finalize()`

**Segmentation Strategies:**
- **Turn-based**: Single segment per complete utterance (most presets)
- **Sentence-based**: Multiple segments per utterance (SCRIBE, CAPTIONS)

**Real-time Events:**
- **ADD_PARTIAL_SEGMENT**: Live updates as you speak
- **ADD_SEGMENT**: Finalized transcription segments
- **END_OF_TURN**: Turn completion detection

**Speaker Identification:**
- Automatic speaker labeling (S1, S2, etc.)
- Diarization enabled by default in presets

## Configuration Options

### Using Different Presets

```python
# Quick finalization for real-time captions
config = VoiceAgentConfigPreset.load("low_latency")

# Note-taking with sentence-level segments
config = VoiceAgentConfigPreset.load("scribe")

# ML-based turn detection for interviews
config = VoiceAgentConfigPreset.load("conversation_smart_turn")
```

### Custom Overlay on Presets

```python
# Start with a preset and customize
base_config = VoiceAgentConfigPreset.load("conversation_adaptive")

custom_config = VoiceAgentConfig(
    language="es",  # Change to Spanish
    enable_diarization=False,  # Disable speaker labels
)

# Merge custom settings with preset
config = VoiceAgentConfigPreset._merge_configs(base_config, custom_config)
```

### Enable SMART_TURN Mode

SMART_TURN dependencies are already included in `requirements.txt`. If installing manually:

```bash
# Install ML dependencies individually
pip install certifi>=2025.10.5
pip install onnxruntime>=1.19.0,<2
pip install transformers>=4.57.0,<5

# Or use the Voice SDK bundle
pip install speechmatics-voice[smart]
```

## Understanding Turn Detection Behavior

### Comparison: Sentence vs Turn Segmentation

**Standard Presets (Turn-Based):**
```
Input: "Hello. How are you today?"

Output:
[S1]: Hello. How are you today.
[END OF TURN]

Result: 1 segment per turn
```

**SCRIBE/CAPTIONS Presets (Sentence-Based):**
```
Input: "Hello. How are you today?"

Output:
[S1]: Hello.
[S1]: How are you today.
[END OF TURN]

Result: 2 segments (one per sentence)
```

Sentence-based segmentation is perfect for:
- Structured note-taking
- Creating bullet-point lists
- Generating captions with line breaks
- Separating distinct thoughts

### Silence Threshold Impact

| Preset | Threshold | Effect | Best For |
|--------|-----------|--------|----------|
| LOW_LATENCY | 0.5s | May split mid-sentence | Fast speakers, captions |
| CONVERSATION_ADAPTIVE | 1.0s | Balances speed and accuracy | General conversation |
| SCRIBE | 1.2s | Waits for complete thoughts | Dictation, notes |

## Next Steps

- **[Pipecat Integration](../../integrations/pipecat/simple-voice-bot/)** - Build voice agents with Pipecat framework
- **[Real-time Translation](../05-multilingual-translation/)** - Add multilingual support
- **[Audio Intelligence](../04-audio-intelligence/)** - Sentiment and topic detection
- **[Turn Detection](../07-turn-detection/)** - Basic RT SDK turn detection

## Troubleshooting

**PyAudio Installation Issues**

**Windows:**
```bash
# If pip install pyaudio fails, try:
pip install pipwin
pipwin install pyaudio

# Or download pre-built wheel from:
# https://www.lfd.uci.edu/~gohlke/pythonlibs/#pyaudio
```

**Mac:**
```bash
# Install portaudio first
brew install portaudio
pip install pyaudio
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install portaudio19-dev
pip install pyaudio
```

**"SMART_TURN not working"**
```bash
# Dependencies should be installed from requirements.txt
# If you skipped them, install manually:
pip install certifi>=2025.10.5 onnxruntime>=1.19.0,<2 transformers>=4.57.0,<5

# Or use the Voice SDK bundle
pip install speechmatics-voice[smart]
```

**"Microphone not available" message**
- Check that PyAudio is installed: `pip list | grep PyAudio`
- Verify microphone permissions in system settings
- Test microphone with another application

**"Too many short segments with FIXED mode"**
- Speaker may have slow speech or frequent pauses
- Try **CONVERSATION_ADAPTIVE** instead of LOW_LATENCY
- Or use **SCRIBE** for longer silence threshold (1.2s)

**"Not detecting turn endings"**
- Ensure you're pausing for the silence threshold duration
- Check silence threshold for your selected preset
- EXTERNAL mode requires manual `await client.finalize()` call

**"Authentication failed" error**
- Verify API key in `.env` file
- Check your key at [portal.speechmatics.com](https://portal.speechmatics.com/)
- Ensure no extra spaces in `.env` file

## Resources

- [Voice SDK Documentation](https://docs.speechmatics.com/voice-sdk)
- [Turn Detection Guide](https://docs.speechmatics.com/features/turn-detection)
- [Voice Agent Presets Reference](https://github.com/speechmatics/speechmatics-python-sdk/tree/main/sdk/voice)
- [Real-time API Reference](https://docs.speechmatics.com/api-ref/realtime-transcription-websocket)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Voice Agent (Real-time)
**Languages**: Python

[Back to Basics](../README.md)
