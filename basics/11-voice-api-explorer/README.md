# Voice API Explorer - Unified WebSocket API Demo

**Explore every feature of the Speechmatics Voice API - a single WebSocket endpoint for both real-time transcription and voice agent modes.**

> [!WARNING]
> The Voice API is currently in **preview** and is an **experimental feature**. Endpoints, message formats, and behaviour may change without notice. Do not use in production workloads.
>
> We value your feedback - [submit feedback](https://docs.google.com/forms/d/e/1FAIpQLSc-6GQXYx_0M-X0Uu_uB_4XyDL009jMv3hBJAFw7kD98AILJg/viewform). Areas of interest:
> - **Integration experience** - documentation, SDKs, API messages/metadata
> - **Accuracy & latency** - including data capture (e.g. phone numbers, spell-outs of names/account numbers)
> - **Turn detection** - experience with different profiles (agile, adaptive, smart, external)
> - **Missing capabilities** - what would make your product better
> - **Production blockers** - what would stop you using this in production

The Voice API is a unified WebSocket endpoint for real-time transcription and voice agent capabilities. Clients stream audio in and receive transcription events out. The mode (RT or Voice) is determined automatically from the URL path. This demo showcases all features across four interactive scenarios.

## What You'll Learn

- How to connect to the Voice API WebSocket with authentication
- **RT mode** (`/v2`): real-time transcription with partials, finals, and confidence
- **Voice mode** (`/v2/agent/{profile}`): segments, turns, speaker tracking, and session metrics
- All **four voice profiles**: `agile`, `adaptive`, `smart`, `external`
- **Mid-session control**: `ForceEndOfUtterance`, `UpdateSpeakerFocus`, `GetSpeakers`
- The complete **session lifecycle**: `StartRecognition` → Audio → `EndOfStream` → `EndOfTranscript`

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+** or **Node.js 18+**
- **Microphone**: Any working input device (built-in or USB) - used by default
- **PyAudio** (Python): Installed automatically with `pip install -r requirements.txt` (see platform notes below)
- **SoX** (JavaScript, Mac/Linux only): Required for microphone recording on Mac/Linux (see platform notes below). Windows uses native audio APIs - no extra install needed.

## Quick Start

<details>
<summary><b>Python - Click to expand setup and usage instructions</b></summary>

<br>

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
python -m venv venv
source venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

> **PyAudio installation** requires the PortAudio system library:
> - **Windows:** `pip install pyaudio` works out of the box
> - **Mac:** `brew install portaudio && pip install pyaudio`
> - **Linux (Debian/Ubuntu):** `sudo apt install portaudio19-dev && pip install pyaudio`

**Step 3: Configure your API key**

```bash
cp ../.env.example ../.env
# Edit ../.env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run the demo**

```bash
# Interactive menu - records from your microphone by default
python main.py

# Or run a specific demo
python main.py rt              # RT mode transcription
python main.py voice           # Voice mode (adaptive)
python main.py profiles        # Compare all profiles
python main.py advanced        # Speaker focus, ForceEOU
python main.py all             # Run everything

# Use a WAV file instead of the microphone
python main.py --audio path/to/file.wav rt

# Debug mode - dumps full WebSocket URL, StartRecognition payload, and raw JSON for every message
python main.py --debug rt
python main.py --debug --audio path/to/file.wav voice
```

By default, the demo records from your microphone - select a demo, speak, press Enter to stop, and the recorded audio is sent to the API. Use `--audio` to provide a pre-recorded 16-bit mono WAV file instead.

</details>
<br>
<details>
<summary><b>JavaScript (Node.js) - Click to expand setup and usage instructions</b></summary>

<br>

**Step 1: Install dependencies**

```bash
cd javascript
npm install
```

> **Microphone recording:**
> - **Windows:** Works out of the box - uses native Windows MCI audio APIs (no extra install needed). A small `.mic_recorder.exe` is compiled on first use via .NET Framework.
> - **Mac:** `brew install sox`
> - **Linux (Debian/Ubuntu):** `sudo apt install sox`
>
> On Mac/Linux, microphone recording uses [SoX](https://sox.sourceforge.net/) via `node-record-lpcm16`. If SoX is not installed, you can still use `--audio` to provide a WAV file instead.

**Step 2: Configure your API key**

```bash
cp ../.env.example ../.env
# Edit ../.env and add your SPEECHMATICS_API_KEY
```

**Step 3: Run the demo**

```bash
# Interactive menu - records from your microphone by default
node main.js

# Or run a specific demo
node main.js rt              # RT mode transcription
node main.js voice           # Voice mode (adaptive)
node main.js profiles        # Compare all profiles
node main.js advanced        # Speaker focus, ForceEOU
node main.js all             # Run everything

# Use a WAV file instead of the microphone
node main.js --audio path/to/file.wav rt

# Debug mode
node main.js --debug rt
node main.js --debug --audio path/to/file.wav voice
```

</details>

## Project Structure

Both implementations split the code into three files with the same responsibilities:

| File | Purpose |
|------|---------|
| **`main.py` / `main.js`** | CLI entry point - argument parsing, interactive menu, audio input handling, and demo orchestration |
| **`demos.py` / `demos.js`** | All four demo functions, each configuring and running a specific API scenario |
| **`core.py` / `core.js`** | Shared infrastructure - constants, audio utilities (mic recording, WAV parsing), WebSocket session runner, and ANSI-coloured message formatter |

```
11-voice-api-explorer/
├── python/
│   ├── main.py              # CLI entry point
│   ├── demos.py             # 4 demo functions
│   ├── core.py              # Session runner, audio utils, message formatter
│   └── requirements.txt
├── javascript/
│   ├── main.js              # CLI entry point
│   ├── demos.js             # 4 demo functions
│   ├── core.js              # Session runner, audio utils, message formatter
│   └── package.json
├── assets/
│   └── sample_mono.wav      # Sample audio for testing
├── .env.example
└── README.md
```

## How It Works

> [!NOTE]
> This demo connects directly to the Voice API WebSocket using raw `websockets` (Python) or `ws` (Node.js) - no SDK wrapper - to demonstrate the full protocol:
>
> 1. **Record** - capture audio from your microphone (or load a WAV file via `--audio`)
> 2. **Connect** - open a WebSocket to `/v2` (RT) or `/v2/agent/{profile}` (Voice) with Bearer token auth
> 3. **StartRecognition** - send a JSON config as the first frame
> 4. **Stream audio** - send the recorded PCM buffer as binary frames at a paced rate
> 5. **Receive events** - handle transcription, speaker, and metric messages
> 6. **EndOfStream** - signal no more audio; wait for `EndOfTranscript`

### Authentication

Every connection requires a Speechmatics API key via the `Authorization` header:

```
Authorization: Bearer <API_KEY>
```

Alternatively, pass it as a query parameter: `wss://server/v2?api_key=<API_KEY>`.

### Endpoints

| Environment | Server |
|-------------|--------|
| Preview     | `wss://preview.rt.speechmatics.com` |
| Local       | `ws://localhost:8000` |

### Profiles

The mode is selected by the URL path:

| Profile | Mode | Path | Languages | Description |
|---------|------|------|-----------|-------------|
| *(none)* | RT | `/v2` | All | Real-time transcription with partials |
| `agile` | Voice | `/v2/agent/agile` | All | Fastest response, VAD-based turn detection |
| `adaptive` | Voice | `/v2/agent/adaptive` | All | Adapts to speaker pace and disfluency |
| `smart` | Voice | `/v2/agent/smart` | Limited (22) | Acoustic model for turn completion |
| `external` | Voice | `/v2/agent/external` | All | Client-controlled turn detection |

> [!NOTE]
> The `smart` profile uses an acoustic model for turn prediction and only supports: Arabic, Bengali, Chinese, Danish, Dutch, English, Finnish, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Marathi, Norwegian, Polish, Portuguese, Russian, Spanish, Turkish, Ukrainian, Vietnamese. All other profiles support all languages.

Profiles support versioning: `adaptive:latest`, `adaptive:2026-02-10`.

### RT Mode vs Voice Mode

**RT mode** (`/v2`) gives you raw transcription - partials stream in as you speak, finals arrive when words are confirmed, and `EndOfUtterance` fires at silence gaps. You get word-level timestamps, confidence scores, and optional translation. There is no concept of turns or speakers - just a continuous stream of text.

**Voice mode** (`/v2/agent/{profile}`) adds a conversation layer on top. Instead of individual transcript chunks, you get **segments** that accumulate the full utterance, **turns** that group segments into conversational units, and **speaker tracking** that identifies who is talking. Voice mode also provides rich annotations (`has_disfluency`, `ends_with_eos`, `fast_speaker`) and metrics (`SpeakerMetrics`, `SessionMetrics`) not available in RT mode.

> [!NOTE]
> In Voice mode the server sends **both** RT-style messages (`AddPartialTranscript`/`AddTranscript`) and Voice-style messages (`AddPartialSegment`/`AddSegment`) simultaneously. Segments accumulate the full turn context while partials only show the current chunk.

### How Each Profile Detects Turns

| Profile | How It Works | Typical Behaviour | Best For |
|---------|-------------|-------------------|----------|
| **Agile** | Uses VAD (Voice Activity Detection) to find silence gaps. When silence exceeds a short threshold, the turn ends immediately. | Fast but aggressive - may split mid-sentence if the speaker pauses briefly (e.g. "I went to the shop *and.*" becomes a separate turn). | Lowest latency use cases where speed matters more than accuracy. Real-time captions, live subtitles. |
| **Adaptive** | Monitors speech pace, disfluencies (um, uh), and punctuation patterns. Dynamically adjusts how long to wait during silence before ending a turn. | Waits longer when the speaker is hesitating or mid-thought. Cuts cleanly at sentence boundaries. Handles "um... and I love chocolate" as one turn, not two. | General voice agents. Best balance of speed and accuracy for most applications. |
| **Smart** | Runs an acoustic model that predicts the probability a turn is complete. Only ends the turn when the model is confident (e.g. probability > threshold). | Very cautious - holds the turn open even during long pauses if the model thinks the speaker isn't done. May add ~3s+ of extra wait time. | Critical accuracy scenarios where incorrect splits are unacceptable. Dictation, medical transcription, legal recordings. |
| **External** | No automatic turn detection. The server never ends a turn on its own - the client must send `ForceEndOfUtterance` to trigger it. | Turn stays open indefinitely until the client decides. In this demo, `ForceEndOfUtterance` is sent automatically 0.5s after audio ends. | Push-to-talk interfaces, custom VAD systems, framework integrations (Pipecat, LiveKit) where the client controls turn boundaries. |

### Example: Same Audio, Different Results

Input: *"Today I went to the shop and I bought a couple of different things. One of the things I bought was the food for the cat."*

| Profile | Turns | What Happened |
|---------|-------|---------------|
| **Agile** | 3 | Split at tiny pauses: "...the shop *and.*" / "I bought...I bought *was.*" / "The food for the cat" |
| **Adaptive** | 2 | Clean sentence boundaries: "...I bought a couple of different things." / "One of the things I bought was the food for the cat." |
| **Smart** | 1 | Held entire utterance as one turn - acoustic model predicted only 20% chance the turn was complete at the mid-sentence pause |
| **External** | 1 | Entire utterance until `ForceEndOfUtterance` was sent by the client |

> [!TIP]
> Run `python main.py profiles` (or `node main.js profiles`) to see this comparison live with your own audio.

## Demos

### Demo 1: RT Mode - Transcription (`rt`)

Streams audio via `/v2` and displays partial and final transcription results with word-level confidence scores.

**Messages shown:** `RecognitionStarted`, `AddPartialTranscript`, `AddTranscript`, `EndOfUtterance`, `EndOfTranscript`

### Demo 2: Voice Mode - Adaptive (`voice`)

Connects to `/v2/agent/adaptive` and demonstrates the segment-based output format with speaker tracking and session metrics.

**Messages shown:** `AddPartialSegment`, `AddSegment` (with annotations like `has_partial`, `has_final`, `fast_speaker`), `SpeakerStarted`, `SpeakerEnded`, `StartOfTurn`, `EndOfTurn`, `SessionMetrics`, `SpeakerMetrics`

### Demo 3: Profile Comparison (`profiles`)

Runs the same audio through all four voice profiles to show how each handles turn detection differently.

For the `external` profile, the demo sends `ForceEndOfUtterance` to manually trigger utterance boundaries.

### Demo 4: Advanced Features (`advanced`)

Demonstrates mid-session control with `diarization: "speaker"`:

1. **GetSpeakers** - request speaker identification data → receives `SpeakersResult`
2. **UpdateSpeakerFocus** with `focus_mode: "retain"` - non-focused speakers tracked as passive
3. **ForceEndOfUtterance** - immediately finalise the current utterance
4. **UpdateSpeakerFocus** with `focus_mode: "ignore"` - non-focused speakers dropped entirely

## Configuration Reference

### StartRecognition Payload

```json
{
    "message": "StartRecognition",
    "transcription_config": {
        "language": "en",
        "operating_point": "enhanced",
        "enable_partials": true,
        "diarization": "speaker",
        "additional_vocab": [
            {"content": "Speechmatics", "sounds_like": ["speech matics"]}
        ]
    },
    "audio_format": {
        "type": "raw",
        "encoding": "pcm_s16le",
        "sample_rate": 16000
    }
}
```

### Diarization Options

The `diarization` field in `transcription_config` controls speaker labelling:

| Value | Modes | Behaviour |
|-------|-------|-----------|
| `"none"` | Both | Speakers labelled as **UU** (unknown). `GetSpeakers` and `UpdateSpeakerFocus` are disabled. |
| `"speaker"` | Both | Speakers labelled as **S1**, **S2**, etc. Enables `GetSpeakers` and `UpdateSpeakerFocus`. |
| `"channel"` | RT only | One speaker per audio channel. |
| `"channel_and_speaker"` | RT only | Per-channel diarization with speaker labels. |

### Voice Mode Restrictions

The following `transcription_config` fields are **not available** in Voice mode (ignored with a warning):
`enable_partials`, `streaming_mode`, `audio_filtering_config`, `transcript_filtering_config`, `speaker_diarization_config`, `conversation_config`, `max_delay`, `max_delay_mode`

`translation_config` and `audio_events_config` are **not supported** in Voice mode (causes `Error` and connection close).

### Client → Server Messages

| Message | Mode | Description |
|---------|------|-------------|
| `StartRecognition` | Both | First message. Configures transcription and mode. |
| Audio (binary) | Both | Raw PCM frames matching declared `audio_format`. |
| `EndOfStream` | Both | Signals no more audio. RT mode accepts `last_seq_no`. |
| `ForceEndOfUtterance` | Both | Finalise current utterance immediately. Supports optional `timestamp` and `channel` fields in RT. |
| `UpdateSpeakerFocus` | Voice | Update speaker focus config mid-session. Requires `diarization: "speaker"`. |
| `GetSpeakers` | Both | Request speaker identification data. |

### Server → Client Messages

**Always forwarded (both modes):**

| Message | Description |
|---------|-------------|
| `RecognitionStarted` | Session started. Contains session ID and language pack info. |
| `EndOfTranscript` | Session complete. No further messages. |
| `EndOfUtterance` | Utterance boundary detected. |
| `Info` | Informational (sub-types: `recognition_quality`, `endpoint_info`, etc.). |
| `Warning` | Non-fatal warning. |
| `Error` | Error - session may end. |
| `SpeakersResult` | Speaker identification data (response to `GetSpeakers`). |

**Voice mode defaults:**

| Message | Description |
|---------|-------------|
| `AddPartialSegment` | Interim transcription segment with speaker and annotations. |
| `AddSegment` | Finalised segment. `is_eou: true` marks utterance boundary. |
| `SpeakerStarted` | Speaker began speaking. |
| `SpeakerEnded` | Speaker stopped speaking. |
| `StartOfTurn` | New conversational turn. |
| `EndOfTurn` | Current turn ended. |
| `SessionMetrics` | Aggregate session stats. |
| `SpeakerMetrics` | Per-speaker stats. |

**RT mode defaults:**

| Message | Description |
|---------|-------------|
| `AddPartialTranscript` | Interim transcription with word-level results. |
| `AddTranscript` | Finalised transcription with confidence and punctuation. |
| `AudioEventStarted` | Audio event detected (e.g. music). |
| `AudioEventEnded` | Audio event ended. |

## Key Features Demonstrated

**RT Mode (Real-Time Transcription):**
- Partial and final transcription with word-level confidence
- Utterance boundary detection

**Voice Mode (Voice Agent):**
- Segment-based output with rich annotations (`has_disfluency`, `ends_with_eos`, `fast_speaker`)
- Speaker tracking with `SpeakerStarted`/`SpeakerEnded` lifecycle events
- Turn detection across four profiles (agile, adaptive, smart, external)
- Session and speaker metrics (word count, volume, processing time)

**Mid-Session Control:**
- `ForceEndOfUtterance` - manually finalise utterances
- `UpdateSpeakerFocus` - retain or ignore non-focused speakers
- `GetSpeakers` - request speaker identification data

## Expected Output

```
Select a demo:
  1) rt             - RT mode transcription
  2) voice          - Voice mode (adaptive)
  3) profiles       - Compare all voice profiles
  4) advanced       - Speaker focus & ForceEOU
  5) all            - Run all demos
Choice [1-5]: 1

  Recording... speak now, then press Enter to stop.

  Recorded 5.2s of audio (16000Hz, 16-bit mono)

================================================================================
  Demo 1: RT Mode - Real-Time Transcription
================================================================================

  Audio: microphone (5.2s, 16000Hz, 16-bit mono)
  Mode:     RT (no profile)
  Endpoint: /v2

    [RecognitionStarted] session=12911500-8773-4e... lang=English
    [Info:recognition_quality] Running recognition using a broadcast model quality.
    [Partial]     Good
    [Partial]     Good evening
    [Final]       Good evening.  (avg confidence: 0.99)
    [EndOfUtterance] 0.0s - 1.4s
    [Partial]     How are
    [Partial]     How are you doing
    [Final]       How are you doing?  (avg confidence: 0.98)
    [EndOfTranscript] Session complete.
```

## Audio Input

**Microphone (default):** The demo records from your default input device using PyAudio (Python) or native APIs (Node.js on Windows) / SoX (Node.js on Mac/Linux). Select a demo, speak, then press Enter - the recorded buffer is replayed to the API for each session.

**WAV file (`--audio`):** Pass `--audio path/to/file.wav` to use a pre-recorded file instead. The file must be 16-bit mono WAV (any sample rate; 16 kHz recommended).

Convert with ffmpeg:
```bash
ffmpeg -i input.mp3 -acodec pcm_s16le -ac 1 -ar 16000 output.wav
```

The Voice API expects raw PCM audio:
- **Encoding:** `pcm_s16le` (16-bit signed little-endian)
- **Sample rate:** 16000 Hz
- **Channels:** Mono (1)

## Debug Mode

Pass `--debug` to see the full protocol exchange - useful for troubleshooting configuration issues or reporting bugs.

```bash
python main.py --debug voice
# or
node main.js --debug voice
```

Debug mode outputs:
- **WebSocket URL** - the exact URL being connected to (e.g. `wss://preview.rt.speechmatics.com/v2/agent/adaptive`)
- **StartRecognition payload** - the full JSON config sent as the first frame
- **Raw JSON for every message** - complete server responses, not just formatted summaries

> [!TIP]
> Combine `--debug` with `--audio` for reproducible bug reports:
> - Python: `python main.py --debug --audio ../assets/sample_mono.wav rt`
> - Node.js: `node main.js --debug --audio ../assets/sample_mono.wav rt`

## Next Steps

- **[Voice Agent Turn Detection](../08-voice-agent-turn-detection/)** - SDK presets for turn detection with FIXED, ADAPTIVE, and Smart Turn modes
- **[Voice Agent Speaker ID](../09-voice-agent-speaker-id/)** - Speaker identification and diarization with the Voice SDK
- **[Multilingual Translation](../05-multilingual-translation/)** - Batch and real-time translation
- **[Channel Diarization](../10-channel-diarization/)** - Multi-channel audio with per-channel transcription

## Troubleshooting

**"No default input device" / PyAudio errors**
- Check that a microphone is connected and set as the default input device
- On Mac: `brew install portaudio` then reinstall PyAudio
- On Linux: `sudo apt install portaudio19-dev` then reinstall PyAudio
- Alternatively, use `--audio path/to/file.wav` to skip the microphone

**"Warning: Very short recording"**
- Make sure your microphone is not muted and is picking up audio
- Speak before pressing Enter - the recording starts immediately

**"Error: Audio file not found"**
- When using `--audio`, ensure the WAV file path exists and is a valid 16-bit mono WAV

**"ConnectionClosed code=1008"**
- API key is missing or invalid. Check your `.env` file.

**"Expected 16-bit audio" / "Expected mono audio"**
- Convert your audio: `ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav`

**"Timeout: RecognitionStarted not received"**
- Check your network connection and server URL
- Verify the server is reachable: `curl -I https://preview.rt.speechmatics.com`

**"Error message received and connection closed" (Voice mode)**
- You may have sent `translation_config` or `audio_events_config` in Voice mode, which is not supported
- Check for unsupported `transcription_config` fields (see Voice Mode Restrictions above)

**"Microphone recording requires SoX" (Node.js on Mac/Linux)**
- Install SoX: Mac `brew install sox`, Linux `sudo apt install sox`
- Or use `--audio path/to/file.wav` to skip the microphone
- On Windows, mic recording uses native APIs and does not require SoX

**"UpdateSpeakerFocus returns Error"**
- `diarization` must be `"speaker"` in the initial `StartRecognition` config

## Resources

- [Speechmatics Portal](https://portal.speechmatics.com/) - get your API key
- [Voice API Documentation](https://docs.speechmatics.com/private/voice-agent-api)
- [Voice SDK Documentation](https://docs.speechmatics.com/voice-agents/voice-sdk)
- [Speechmatics Python SDK](https://github.com/speechmatics/speechmatics-python-sdk)
- [Speechmatics JavaScript SDK](https://github.com/speechmatics/speechmatics-js-sdk)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)
- Join the conversation on [Discord](https://discord.gg/speechmatics)

---

**Time to Complete**: 20 minutes
**Difficulty**: Intermediate
**API Mode**: Real-Time + Voice (WebSocket)

[Back to Basics](../) | [Back to Academy](../../README.md)
