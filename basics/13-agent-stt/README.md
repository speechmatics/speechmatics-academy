# Agent STT - Segments, Turns and Speakers

**Transcribe for voice agents with the Agent STT service: whole segments instead of word groups, the speech and turn events that tell an agent when to respond, speaker labels, and a choice of who closes each turn.**

The `speechmatics-agent-stt` package is a thin client over `speechmatics-rt` aimed at one job: feeding a voice agent. Turn detection is the service's job by default: its VAD closes each turn and streaming audio is all you supply. `TurnDetectionMode.EXTERNAL` hands that decision to your application instead. This example registers a handler for every message the service sends, prints them as they arrive, and shows what the session leaves behind.

## What You'll Learn

- **Segments, not word groups**: `AddSegment` replaces the Real-Time API's `AddTranscript`, and one turn usually produces several segments.
- **Which event means "respond now"**: `EndOfTurn`, not `SpeechEnded` - a pause mid-sentence produces `SpeechEnded` while the turn stays open.
- **Who closes the turn**: the service's VAD by default, or your own endpointing calling `finalize()`. This example wires up Silero VAD for the second case.
- **Speaker labels and voiceprints**: segments carry a `speaker`, and `GetSpeakers` returns an identifier you can pass back to recognize the same person in a later session.
- **What the client keeps**: the transcript, the segments, the speech and turn timeline, and the raw message log.

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+**
- **16 kHz mono 16-bit PCM audio**: the service takes nothing else. The bundled `assets/sample.wav` already is - a 28-second two-speaker clip from the [Python SDK](https://github.com/speechmatics/speechmatics-python-sdk)'s test fixtures.
- **Silero VAD** (optional): `pip install silero-vad torch numpy`, only for `--external`.
- **PyAudio** (optional): `pip install pyaudio`, only for `--mic`. Both extras stay out of `requirements.txt` so the default run installs light.

## Quick Start

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

> [!TIP]
> In PowerShell, run `.\.venv\Scripts\Activate.ps1`. The extensionless `activate` resolves to `activate.bat`, which sets its variables in a child `cmd` process that exits immediately - it looks like it worked and changes nothing.

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API key**

```bash
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Run the example**

```bash
python main.py
```

Then each flag adds one thing:

```bash
python main.py --mic                          # your microphone (pip install pyaudio)
python main.py --external                     # you close the turns (pip install silero-vad torch numpy)
python main.py --external --min-silence 800   # how long a pause has to be
python main.py --speakers                     # fetch reusable voiceprints
python main.py --no-partials                  # finalized segments only
python main.py --language de
python main.py path/to/16khz-mono.wav
```

## How It Works

> [!NOTE]
> The shape is the SDK quickstart, with a handler per message:
>
> 1. **Two configs**: `TranscriptionConfig` for transcription, `TurnConfig` for turn taking. They are siblings on the wire, and the turn config is fixed for the session.
> 2. **Handlers before the session opens**, so nothing can arrive unhandled.
> 3. **`async with client`**: entering waits until the service is ready for audio; leaving sends `EndOfStream` and waits for the flush, so the transcript is complete afterwards.
> 4. **Frames arrive from one async generator**, whether the source is the microphone or a file paced to real time - so the send loop is the same either way.

### Code Walkthrough

The core is the quickstart: build a client, register handlers, stream audio, read the transcript.

```python
client = AgentSttAsyncClient(
    transcription_config=TranscriptionConfig(language="en", enable_partials=True)
)

@client.on(ServerMessageType.ADD_SEGMENT)
def handle_segment(message):
    print(message["segment"]["transcript"])

async with client:
    async for frame in audio_frames(args):
        await client.send_audio(frame)

print(client.transcript)
```

Read the text from `message["segment"]["transcript"]` and the speaker from `message["segment"]["speaker"]`. Partials replace each other, so display the latest and never concatenate them.

`EndOfTurn` is the message that matters for an agent - it is always the turn's last, arriving after the final `AddSegment`:

```python
@client.on(ServerMessageType.END_OF_TURN)
def on_turn_end(message):
    print(f"respond now, speaker finished at {message['metadata']['end_time']:.2f}s")
```

**Handlers are synchronous callbacks, so they must not block.** Anything slow belongs on a queue or in a thread, or it stalls the audio being sent. The same rule applies to the send loop, which is why the VAD below runs in a worker thread:

```python
if vad is not None and await asyncio.to_thread(speech_ended, vad, frame):
    await client.force_end_of_utterance()
```

#### Closing turns yourself

With `TurnDetectionMode.EXTERNAL` the service runs no VAD, sends no `SpeechStarted` or `SpeechEnded`, and **nothing closes a turn but you**. This example uses Silero VAD for External:

```python
from silero_vad import VADIterator, load_silero_vad

# The service exposes no silence trigger, so this is the dial that decides how long a
# pause has to be before the turn closes.
vad = VADIterator(load_silero_vad(), sampling_rate=16000, min_silence_duration_ms=500)
```

Silero reads 512-sample windows at 16 kHz, which is exactly one frame here, so each frame goes to the VAD as it goes to the service. Swap Silero for Pipecat's or LiveKit's end-of-speech event and nothing else changes - `finalize()` is the whole interface.

> [!WARNING]
> `finalize()` schedules its send on the running event loop, so it only works from synchronous code already on that loop's thread. From a genuinely separate thread - a PyAudio callback, a VAD worker - it finds no loop, logs a warning through a `NullHandler` (so you see nothing) and sends nothing. Use `loop.call_soon_threadsafe(client.finalize)` there instead.

#### Recognizing a speaker again

Labels like `S1` are per-session. Ask for voiceprints before the session closes:

```python
await client.send_message({"message": ClientMessageType.GET_SPEAKERS})
```

Store the `speaker_identifiers` from the `SpeakersResult`, then pass them back later under a name of your own:

```python
SpeakerDiarizationConfig(
    speakers=[SpeakerIdentifier(label="Edgar", speaker_identifiers=["<from SpeakersResult>"])]
)
```

> [!IMPORTANT]
> Your label must not look like the service's internal format: `S1`, `S2` and `UU` are rejected, and the session fails to start.

## Expected Output

Each line is a message as it arrives, and the times are positions in the audio. These blocks are from `python main.py --no-partials`; the default run is the same plus a running `[partial]` line for every interim update, which is around 45 more lines on this sample.

```
Turns closed by the service

Streaming 27.9s of audio

[speech]  start at 0.48s
[speech]  end at 1.98s
[turn]    start at 0.24s
[final]   S1: Welcome to Speechmatics.
[turn]    end at 1.96s
[speech]  start at 3.65s
[turn]    start at 3.56s
[speech]  end at 7.04s
[speech]  start at 7.17s
[speech]  end at 7.58s
[speech]  start at 7.78s
[final]   S1: We're delighted that you've decided to try our speech to text software.
[speech]  end at 9.50s
[speech]  start at 9.73s
[speech]  end at 10.66s
[final]   S2: Hello. This is a test. One two. Three. 123.
[turn]    end at 10.72s
```

Four `[speech]` pairs sit inside that second turn. They are voice activity, not turn boundaries - which is exactly why an agent should wait for `[turn] end` instead. Note also that `[turn] start at 0.24s` is reported *after* the speech events inside it, because `StartOfTurn` fires on the first recognized word rather than the first sound.

Then the summary:

```
Session   10a03f71-d358-4c9e-a800-7e6ad3370def  |  English
Messages  873 AudioAdded, 11 SpeechStarted, 11 SpeechEnded, 9 AddSegment, 6 StartOfTurn, 6 EndOfTurn, 2 Info, 1 RecognitionStarted, 1 EndOfTranscript
Timeline  34 speech and turn events

Segments (9)
    0.24s -   1.96s   S1  Welcome to Speechmatics.
    3.56s -   7.16s   S1  We're delighted that you've decided to try our speech to text software.
    7.20s -  10.72s   S2  Hello. This is a test. One two. Three. 123.
   12.04s -  12.40s   S2  To get.
   12.40s -  16.72s   S1  Going, just create an API key and submit a transcription request to our API.
   17.56s -  19.68s   S1  We hope you'll be very impressed by the results.
   20.28s -  20.88s   S1  The results.
   20.92s -  22.36s   S2  Really are pretty amazing.
   23.00s -  23.64s   S2  Thank you.

Transcript
  Welcome to Speechmatics. We're delighted that you've decided ...
```

873 `AudioAdded` messages for 28 seconds of audio is why `record_events=False` matters in a long-running agent.

### With `--external`

Silero closes the turns, the `[speech]` lines disappear, and it finds the same six turns the service's own VAD did:

```
Loading Silero VAD (turn ends after 500ms of silence)
Turns closed by this script, via finalize()

[vad]     speech ended -> finalize()
[turn]    start at 0.24s
[final]   S1: Welcome to Speechmatics.
[turn]    end at 2.00s
[turn]    start at 3.52s
[final]   S1: We're delighted that you've decided to try our speech to text software.
[vad]     speech ended -> finalize()
[final]   S2: Hello. This is a test. 123. 123.
[turn]    end at 10.72s
```

### With `--speakers`

```
[speaker] S1  AD1NQVABAAQAAW0ACjlkYzNjNWMwOTQAAXMADC9t...
[speaker] S2  AD1NQVABAAQAAW0ACjlkYzNjNWMwOTQAAXMADC9t...
```

> [!NOTE]
> Transcripts and speaker labels drift as the model is updated, so treat this output as indicative rather than a fixture to diff against.

## Key Features Demonstrated

**Segments:** `AddSegment` and `AddPartialSegment`, with `speaker` and `start_time`/`end_time` metadata. A segment ends at the first boundary it reaches - end of turn, speaker change, or a duration cap - so a turn produces several.

**Turn and speech events:** `StartOfTurn` / `EndOfTurn` in both modes; `SpeechStarted` / `SpeechEnded` in `vad` mode only, for interruption handling and UI feedback.

**Turn ownership:** `TurnConfig(turn_detection_mode=...)`, and `finalize()` / `force_end_of_utterance()` driven by a real Silero VAD.

**Speakers:** `diarization="speaker"`, `SpeakerDiarizationConfig` (`max_speakers`, `speaker_sensitivity`, `prefer_current_speaker`), `GetSpeakers` → `SpeakersResult` voiceprints, and `SpeakerIdentifier` to pass them back.

**Session state:** `client.transcript`, `client.segments`, `client.timeline`, `client.events`, `client.session_info`. Note `client.partial_segment` is cleared by each `AddSegment`, so it is `None` after a clean close.

## Configuration Options

**Endpoint.** Resolution order is the `url` argument, then `SPEECHMATICS_RT_URL`, then the EU endpoint; the `/agent` path segment is appended when missing.

```python
AgentSttAsyncClient(url="wss://eu2.rt.speechmatics.com/v2")  
AgentSttAsyncClient(url="ws://localhost:8000/v2")
AgentSttAsyncClient(app="pipecat/1.0")             
```

**Application name.** `app="pipecat/1.0"` is reported as `sm-app`. This example sends `speechmatics-academy/agent-stt`.

**Audio.** 16 kHz raw PCM only, `pcm_s16le` (the default) or `pcm_f32le`. `mulaw` and every other sample rate are rejected, so telephony audio needs converting first.

**Authentication.** `api_key=` builds a `StaticKeyAuth`. For short-lived tokens use `JWTAuth(api_key, ttl=60)`, which needs `pip install 'speechmatics-rt[jwt]'`.

### What the service accepts

Agent STT takes a subset of the real-time transcription config, and **rejects the rest at `StartRecognition`** - the session fails to start rather than quietly ignoring the field.

| Field | Accepted | Notes |
|-------|----------|-------|
| `language` | Yes | `"multi"` is rejected: Melia is not an Agent STT model |
| `enable_partials` | Yes | off by default; no partials arrive without it |
| `diarization` | Yes | `"speaker"` or `"none"` - `"channel"` is rejected |
| `speaker_diarization_config` | Yes | `max_speakers`, `speaker_sensitivity`, `prefer_current_speaker`, `speakers` |
| `additional_vocab` | Yes | |
| `output_locale`, `domain` | Yes | |
| `transcript_filtering_config` | Yes | |
| `model` | Yes | `Model.LINDEN_1` only, and the default |
| `conversation_config` | **No** | no engine silence trigger - that is what `EXTERNAL` mode is for |
| `max_delay`, `max_delay_mode` | **No** | |
| `enable_entities` | **No** | |
| `punctuation_overrides` | **No** | |
| `audio_filtering_config` | **No** | |
| `streaming_mode` | **No** | |

Two more worth knowing. `ForceEndOfUtterance` is **ignored** in `vad` mode, so switching modes is not something you can do halfway. And in `external` mode each timestamp must be later than the last, or the message comes back as a `Warning` - `audio_seconds_sent` is monotonic, so sending it as this example does is always safe.

> [!NOTE]
> `emit_sentences`, described under [Segmentation](https://docs.speechmatics.com/), is not usable from this example. SDK 0.1.0's `TranscriptionConfig` has no field for it, and the default `eu2` endpoint rejects it outright; it is accepted on the `preview` endpoint only.

## Next Steps

- **[Basic Turn Detection](../07-turn-detection/)** - The same problem on the RT SDK, with engine silence detection
- **[Intelligent Turn Detection](../08-voice-agent-turn-detection/)** - Smart turn presets in the Voice SDK
- **[Speaker ID and Speaker Focus](../09-voice-agent-speaker-id/)** - Deciding which speakers an agent should obey
- **[Voice API Explorer](../11-voice-api-explorer/)** - The raw WebSocket behind these SDKs
- **[Pipecat Voice Bot](../../integrations/pipecat/01-simple-voice-bot/)** - A framework that brings its own endpointing
- **[Medical Microbatching](../../use-cases/07-medical-microbatching/)** - The same Silero VAD, driving batch chunking

## Troubleshooting

**`Error: SPEECHMATICS_API_KEY not set`**
- Add your key to `.env` (copied from `.env.example`), or export it in your shell.

**`pip` is not recognized, or the install goes to the wrong Python**
- The virtual environment is not active. In PowerShell use `.\.venv\Scripts\Activate.ps1`; the extensionless `activate` runs `activate.bat` in a child process and has no effect on your session. `python -m pip` works either way.

**`... is 48000 Hz, 2 channel(s)`**
- Convert it first: `ffmpeg -i input.wav -ar 16000 -ac 1 -sample_fmt s16 converted.wav`

**A traceback ending in `TranscriptionError: Not Authorized`**
- The service rejected the key. Two things to know. It arrives as `TranscriptionError`, not `AuthenticationError` - the latter only covers the `JWTAuth` token path, so a static-key session reports auth failures as an ordinary session error. And it is raised from `async with client`, before any audio device or file is touched, so it masks any other setup problem behind it. The most common cause is not a wrong key but no key at all: `.env` is only read because `load_dotenv()` runs, so check the file exists next to `main.py` and actually contains `SPEECHMATICS_API_KEY=`.

**`Additional property <name> is not allowed`**
- The config carries a field this service does not take. See "What the service accepts".

**No `[speech]` lines appear**
- You are in `--external` mode, where the service runs no VAD. Expected.

**No `[turn] end` ever arrives in `--external` mode**
- Nothing closes a turn but your `finalize()` calls. If the VAD never fires, lower `--min-silence`.

**Turns run together, or cut mid-sentence**
- That is the VAD's threshold, not the service. `--min-silence 800` waits longer; too long and separate utterances merge into one turn.

**`--external needs a VAD`**
- `pip install silero-vad torch numpy`.

**`FutureWarning: torch.jit.load is not supported in Python 3.14+`**
- Silero loads a TorchScript model. Harmless; silence it with `python -W ignore::FutureWarning main.py --external`.

**`PyAudio not installed`**
- `pip install pyaudio`. On Mac add `brew install portaudio` first; on Ubuntu/Debian `sudo apt-get install portaudio19-dev`.

**`Failed building wheel for pyaudio`, or `fatal error C1083: Cannot open include file: 'io.h'`**
- PyAudio 0.2.14 is the latest release and its wheels stop at **CPython 3.13**, so on 3.14 pip falls back to building from source - and that needs two separate things Windows does not have out of the box. `io.h` is a Windows SDK (CRT) header: having Visual Studio is not enough, the SDK is a separate component. Install it from an **elevated** prompt (a non-elevated run fails with `0x80070642`, which is "user cancelled" because the UAC prompt could not be shown):

```bash
winget install --id Microsoft.WindowsSDK.10.0.26100 --accept-package-agreements --accept-source-agreements
```

**`fatal error C1083: Cannot open include file: 'portaudio.h'`**
- This is the second half, and it appears *after* the Windows SDK is installed. PyAudio's sdist does not bundle PortAudio; it expects a prebuilt one and warns `VCPKG_PATH environment variable not set`. The Windows SDK never provides PortAudio. Supply it with [vcpkg](https://vcpkg.io/) and point PyAudio at it:

```bash
vcpkg install portaudio:x64-windows
set VCPKG_PATH=C:\path\to\vcpkg\installed\x64-windows
pip install --no-binary :all: pyaudio
```

> [!TIP]
> On Windows the quickest way out of all of this is to avoid the source build. Either run the example on Python 3.9-3.13, where `pip install pyaudio` fetches an official wheel, or install [PyAudioWPatch](https://pypi.org/project/PyAudioWPatch/) - a Windows fork of PyAudio that does publish a CPython 3.14 wheel and bundles PortAudio, so it needs no compiler at all. It installs under the module name `pyaudiowpatch`, and the SDK's `Microphone` does `import pyaudio` internally, so alias it before importing anything from `speechmatics`:
>
> ```python
> import sys
> import pyaudiowpatch
>
> sys.modules["pyaudio"] = pyaudiowpatch
> ```
>
> Note it is Windows-only, so this is a local convenience rather than something to put in `requirements.txt`.

**`Could not import the PyAudio C module 'pyaudio._portaudio'`**
- PyAudio installed but its compiled extension cannot load, which on Windows almost always means the PortAudio DLL is not next to the `.pyd`. If you built PyAudio yourself, copy the PortAudio DLL into the `pyaudio/` directory inside `site-packages`. If you are not sure where the installed PyAudio came from, reinstall it cleanly - a locally built wheel can linger in pip's cache and get reused silently:

```bash
pip uninstall pyaudio
pip cache remove "pyaudio*"
```

**`PyAudio not installed - install it with: pip install pyaudio`**
- Only affects `--mic`; PyAudio is intentionally not in `requirements.txt`. On Mac: `brew install portaudio && pip install pyaudio`. On Ubuntu/Debian: `sudo apt-get install portaudio19-dev && pip install pyaudio`. Neither platform has the Windows problem above, because the PortAudio dev package provides the headers PyAudio needs.

**`Could not open the microphone`**
- PyAudio is installed and working, but the device would not open: nothing is plugged in, another application holds it exclusively, or it does not support 16 kHz mono capture. This is a different error from the one above, which means PyAudio itself is missing.

## Resources

- [Agent STT Quickstart](https://docs.speechmatics.com/)
- [speechmatics-agent-stt on PyPI](https://pypi.org/project/speechmatics-agent-stt/)
- [Speechmatics Python SDK](https://github.com/speechmatics/speechmatics-python-sdk)
- [API Reference](https://docs.speechmatics.com/api-ref/)
- [Speechmatics Portal](https://portal.speechmatics.com/)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 10 minutes
**Difficulty**: Intermediate
**API Mode**: Agent STT (Real-time)
**Languages**: Python

[Back to Basics](../) | [Back to Academy](../../README.md)
