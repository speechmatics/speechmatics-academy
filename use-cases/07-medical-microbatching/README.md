# Medical Microbatching - Live Transcription via Batch API

**Continuous microphone transcription using the Batch API — no real-time connection required.**

Records audio from your microphone, splits it at natural speech boundaries using Silero VAD, and submits each chunk to the Speechmatics Batch API concurrently. When you press Ctrl+C, any remaining audio is submitted, all outstanding jobs are awaited, and the full transcript is printed in order.

Supports on-premises deployment for HIPAA compliance.

This use case contains two examples, each building on the last:

| Example | Folder | What it adds |
|---|---|---|
| Simple microbatch | `python/simple-microbatch` | Core pipeline: VAD-gated chunking + concurrent batch submission |
| Speaker ID microbatch | `python/speaker-id-microbatch` | Speaker diarization across chunks, with the first speaker labelled DOCTOR |

## What You'll Learn

- Microbatching: splitting a continuous audio stream into chunks for batch submission
- Voice Activity Detection (VAD) with Silero VAD to find natural speech boundaries
- Concurrent batch job submission with `asyncio.gather`
- Using the Speechmatics Batch API (`speechmatics-batch`) for live microphone input
- Capturing microphone audio with the `speechmatics-rt` `Microphone` helper
- *(Speaker ID example)* Using `get_speakers` to identify speakers across chunks
- *(Speaker ID example)* Passing speaker identifiers to subsequent chunks for consistent labelling

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+**
- A working microphone

> [!NOTE]
> Silero VAD requires **PyTorch**. On first run it will download the VAD model weights (~5 MB) automatically.

---

## Example 1: Simple Microbatch

The foundation. Records audio, detects speech boundaries with VAD, and submits each chunk to the Batch API concurrently. No speaker identification — just clean, ordered transcription.

### Quick Start

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python/simple-microbatch
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python/simple-microbatch
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API key**

```bash
cp ../../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Run**

```bash
python main.py
```

Speak into your microphone. Press **Ctrl+C** to stop recording. The full transcript is printed when all jobs complete.

### How It Works

> [!NOTE]
> The pipeline runs in three overlapping stages:
>
> 1. **Capture** — Microphone audio is read in 4096-sample frames (16kHz, 16-bit PCM mono)
> 2. **Detect** — Each frame is passed through Silero VAD in 512-sample windows to detect end-of-speech
> 3. **Submit** — When a speech boundary is found and the chunk exceeds 25 seconds, it is wrapped in a WAV container and submitted to the Batch API as a concurrent `asyncio.Task`
> 4. **Collect** — On Ctrl+C, any remaining audio is submitted, then `asyncio.gather` awaits all jobs and the transcript is printed in chunk order

#### Why microbatching?

Many customers — especially in healthcare — use a microbatching workflow. Hospital networks can be unreliable, and losing a connection mid-consultation can mean losing an entire transcript. Instead of relying on continuous WebSocket streaming, the client splits audio into short chunks and submits each one as a standard REST batch job. If a chunk fails, it can simply be retried.

#### VAD boundary detection

```python
MIN_CHUNK_DURATION_S = 25  # seconds before VAD starts listening for end-of-speech

def _is_speech_end(vad: VADIterator, pcm: bytes) -> bool:
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / INT16_MAX
    tensor = torch.from_numpy(samples)
    windows = (tensor[i : i + VAD_WINDOW] for i in range(0, len(tensor) - VAD_WINDOW + 1, VAD_WINDOW))
    return any((r := vad(w)) and "end" in r for w in windows)
```

Silero VAD requires exactly 512 samples per call at 16 kHz. Each incoming frame is processed in 512-sample windows and `True` is returned on the first end-of-speech event. VAD state is reset after each chunk boundary so the next chunk starts fresh.

#### Batch API submission

```python
from speechmatics.batch import AsyncClient, OperatingPoint, TranscriptionConfig

TRANSCRIPTION_CONFIG = TranscriptionConfig(
    language="en",
    operating_point=OperatingPoint.ENHANCED,
)

async with AsyncClient(api_key=API_KEY) as client:
    result = await client.transcribe(
        wav_buffer,
        transcription_config=TRANSCRIPTION_CONFIG,
        polling_interval=2.0,  # seconds between status polls
    )
    print(result.transcript_text)
```

Each chunk is wrapped in an in-memory WAV container (`io.BytesIO`) — no temporary files are written to disk.

### Configuration

| Constant | Default | Description |
|---|---|---|
| `MIN_CHUNK_DURATION_S` | `25` | Minimum chunk duration before VAD boundary is considered |
| `SAMPLE_RATE` | `16000` | Audio sample rate (Hz) — must match Silero VAD expectation |
| `READ_SIZE` | `4096` | Microphone read frame size (samples) |
| `VAD_WINDOW` | `512` | Silero VAD processing window (samples) — do not change |
| `POLLING_INTERVAL` | `2.0` | Seconds between Batch API job status polls |

> [!TIP]
> **Choosing the right chunk size** — Speechmatics research puts the sweet spot at **25–35 seconds**.
> - **Too short (< 20s):** Less surrounding context reaches the acoustic model, which can reduce accuracy on ambiguous words and domain-specific terminology.
> - **Too long (> 40s):** Transcription time scales with audio duration, so very large chunks increase the wall-clock wait before results appear.
>
> Adjust `MIN_CHUNK_DURATION_S` within this range.

**`TranscriptionConfig` options:**

| Parameter | Options | Description |
|---|---|---|
| `language` | `"en"`, `"es"`, `"fr"`, etc. | Transcription language |
| `operating_point` | `OperatingPoint.STANDARD`, `ENHANCED` | `ENHANCED` gives higher accuracy at higher cost |

> [!TIP]
> For medical use, add `domain="medical"` to `TranscriptionConfig` to activate a specialised clinical vocabulary pack.

### Expected Output

```
2026-04-21 10:32:01 [INFO] Loading Silero VAD model ...
2026-04-21 10:32:03 [INFO] Audio capture started. Press Ctrl+C to stop.
2026-04-21 10:32:30 [INFO] Chunk 0: VAD boundary — submitting ...
2026-04-21 10:33:01 [INFO] Chunk 1: VAD boundary — submitting ...
^C
2026-04-21 10:33:10 [INFO] Recording stopped.
2026-04-21 10:33:10 [INFO] Submitting final partial chunk 2 ...
2026-04-21 10:33:10 [INFO] 3 chunk(s) submitted. Waiting for transcripts ...

--- TRANSCRIPT ---

[Chunk 0 | 10:32:03 → 10:32:30 (27s)]
The patient reports chest pain radiating to the left arm, onset approximately two hours ago.

[Chunk 1 | 10:32:30 → 10:33:01 (31s)]
Blood pressure is one forty over ninety. Heart rate eighty-eight beats per minute, regular rhythm.

[Chunk 2 | 10:33:01 → 10:33:10 (9s)]
We'll order an ECG and troponin levels and review in thirty minutes.
```

---

## Example 2: Speaker ID Microbatch

Builds directly on the simple example, adding speaker diarization that persists across chunk boundaries. The first speaker detected in the first chunk is automatically labelled **DOCTOR** in the transcript; all other speakers keep their default diarization labels.

### What changes from the simple example

- **Chunk 0** is submitted with `get_speakers: True`, which asks the API to return stable speaker identifiers alongside the transcript.
- While chunk 0 is being transcribed in the background, recording continues into chunk 1.
- When chunk 0 returns, the first speaker's identifiers are extracted and stored. The first speaker is mapped to the label `DOCTOR`.
- **Chunks 1+** are submitted with those identifiers passed back in `speaker_diarization_config`, so the model applies consistent labels across the session.
- Chunk 0's own transcript is retroactively updated in the output — the raw diarization label (e.g. `S1`) is replaced with `DOCTOR` before printing.

### Quick Start

**Step 1: Create and activate a virtual environment**

**On Mac/Linux:**
```bash
cd python/speaker-id-microbatch
python3 -m venv .venv
source .venv/bin/activate
```

**On Windows:**
```bash
cd python/speaker-id-microbatch
python -m venv .venv
.venv\Scripts\activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API key**

```bash
cp ../../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

**Step 4: Run**

```bash
python main.py
```

### How It Works

The core capture-and-submit pipeline is identical to the simple example. The speaker ID logic layers on top without changing the chunk timing or submission flow.

#### First chunk: discovering speakers

```python
FIRST_CHUNK_CONFIG = TranscriptionConfig(
    language="en",
    operating_point=OperatingPoint.ENHANCED,
    diarization="speaker",
    speaker_diarization_config={"get_speakers": True},
)
```

Setting `get_speakers: True` tells the API to return a `speakers` list on the result. Each entry contains a `label` (the diarization ID, e.g. `S1`) and a list of `speaker_identifiers` — short acoustic fingerprints the model can match against in future requests.

#### Extracting the doctor's identity

```python
async def _extract_speaker_info(task: asyncio.Task) -> tuple[list[dict], str]:
    result = await task

    if not result.speakers:
        return [], ""

    first = result.speakers[0]
    return [{"label": "DOCTOR", "speaker_identifiers": first.speaker_identifiers}], first.label
```

Only the first speaker is remapped. The raw diarization label (e.g. `"S1"`) is returned alongside the API payload so the chunk 0 output can be corrected retroactively.

#### Subsequent chunks: applying consistent labels

```python
config = TranscriptionConfig(
    language="en",
    operating_point=OperatingPoint.ENHANCED,
    diarization="speaker",
    speaker_diarization_config={"speakers": speaker_labels},
)
```

Passing `speakers` back to the API tells the model to match the incoming audio against the known fingerprints and apply the `DOCTOR` label wherever it finds a match. Any speaker not in the list is labelled by the model's own diarization (e.g. `S2`, `S3`).

#### Retroactive rename of chunk 0

Because chunk 0 was submitted before the speaker identity was resolved, its transcript uses the raw label. After all jobs complete, the output loop replaces it:

```python
if i == 0 and doctor_label:
    lines = [line.replace(f"SPEAKER {doctor_label}:", "SPEAKER DOCTOR:") for line in lines]
```

### Configuration

All constants from the simple example apply. The speaker ID example adds no new tunable constants — the diarization behaviour is controlled entirely through `TranscriptionConfig`.

> [!TIP]
> For medical use, add `domain="medical"` to both `FIRST_CHUNK_CONFIG` and the subsequent chunk config to activate the clinical vocabulary pack alongside speaker diarization.

### Expected Output

```
2026-04-21 14:58:45 [INFO] Loading Silero VAD model ...
2026-04-21 14:58:47 [INFO] Audio capture started. Press Ctrl+C to stop.
2026-04-21 14:59:14 [INFO] Chunk 0: VAD boundary — submitting ...
2026-04-21 14:59:23 [INFO] Chunk 1: VAD boundary — submitting ...
^C
2026-04-21 14:59:31 [INFO] Recording stopped.
2026-04-21 14:59:31 [INFO] Submitting final partial chunk 2 ...
2026-04-21 14:59:31 [INFO] 3 chunk(s) submitted. Waiting for transcripts ...

--- TRANSCRIPT ---

[Chunk 0 | 14:58:47 → 14:59:14 (27s)]
SPEAKER DOCTOR: The patient reports chest pain radiating to the left arm, onset approximately two hours ago.

[Chunk 1 | 14:59:14 → 14:59:23 (8s)]
SPEAKER DOCTOR: Blood pressure is one forty over ninety.
SPEAKER S2: And heart rate?
SPEAKER DOCTOR: Eighty-eight beats per minute, regular rhythm.

[Chunk 2 | 14:59:23 → 14:59:31 (8s)]
SPEAKER DOCTOR: We'll order an ECG and troponin levels and review in thirty minutes.
```

---

## Project Structure

```
07-medical-microbatching/
├── python/
│   ├── simple-microbatch/
│   │   ├── main.py                # Simple microbatch script
│   │   └── requirements.txt
│   └── speaker-id-microbatch/
│       ├── main.py                # Speaker ID microbatch script
│       └── requirements.txt
├── .env.example                   # Environment variable template
└── README.md
```

## Troubleshooting

**"SPEECHMATICS_API_KEY not set"**
- Copy `.env.example` to `.env` and add your key
- Ensure you are running the script from the correct `python/` subdirectory, or that `.env` is found on the path

**"Failed to start microphone"**
- Ensure `PyAudio` is installed: `pip install PyAudio`
- On Mac you may need `brew install portaudio` first
- On Linux: `sudo apt-get install portaudio19-dev`

**"No audio was recorded"**
- The script exits cleanly if Ctrl+C is pressed before any VAD boundary is detected and no audio is buffered

**"Rate limited"**
- Try reducing the polling rate by increasing `POLLING_INTERVAL`

**Speaker labels not appearing in chunk 1+**
- This means chunk 0 did not return any speaker identifiers. Check that `get_speakers: True` is set in `FIRST_CHUNK_CONFIG` and that diarization is enabled
- The script logs a warning if speaker extraction fails, and falls back to submitting subsequent chunks without speaker labels

## Resources

- [Batch API Documentation](https://docs.speechmatics.com/introduction/batch-guide)
- [Speechmatics Batch Python SDK](https://github.com/speechmatics/speechmatics-python)
- [Silero VAD](https://github.com/snakers4/silero-vad)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 15 minutes
**Difficulty**: Intermediate
**API Mode**: Batch

[Back to Use Cases](../) | [Back to Academy](../../README.md)