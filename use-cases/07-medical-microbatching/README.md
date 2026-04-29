# Medical Microbatching - Live Transcription via Batch API

**Continuous microphone transcription using the Batch API — no real-time connection required.**

Records audio from your microphone, splits it at natural speech boundaries using Silero VAD, and submits each chunk to the Speechmatics Batch API concurrently. When you press Ctrl+C, any remaining audio is submitted, all outstanding jobs are awaited, and the full transcript is printed in order.

Supports on-premises deployment for HIPAA compliance.

## What You'll Learn

- Microbatching: splitting a continuous audio stream into chunks for batch submission
- Voice Activity Detection (VAD) with Silero VAD to find natural speech boundaries
- Concurrent batch job submission with `asyncio.gather`
- Using the Speechmatics Batch API (`speechmatics-batch`) for live microphone input
- Capturing microphone audio with the `speechmatics-rt` `Microphone` helper

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **Python 3.9+**
- A working microphone

> [!NOTE]
> Silero VAD requires **PyTorch**. On first run it will download the VAD model weights (~5 MB) automatically.

## Quick Start

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

**Step 3: Configure your API key**

```bash
cp ../.env.example .env
# Edit .env and add your SPEECHMATICS_API_KEY
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Run**

```bash
python main.py
```

Speak into your microphone. Press **Ctrl+C** to stop recording. The full transcript is printed when all jobs complete.

## How It Works

> [!NOTE]
> The pipeline runs in three overlapping stages:
>
> 1. **Capture** — Microphone audio is read in 4096-sample frames (16kHz, 16-bit PCM mono)
> 2. **Detect** — Each frame is passed through Silero VAD in 512-sample windows to detect end-of-speech
> 3. **Submit** — When a speech boundary is found and the chunk exceeds 25 seconds, it is wrapped in a WAV container and submitted to the Batch API as a concurrent `asyncio.Task`
> 4. **Collect** — On Ctrl+C, any remaining audio is submitted, then `asyncio.gather` awaits all jobs and the transcript is printed in chunk order

### Why microbatching?

Many customers — especially in healthcare — use a microbatching workflow. Hospital networks can be unreliable, and losing a connection mid-consultation can mean losing an entire transcript. Instead of relying on continuous WebSocket streaming, the client splits audio into short chunks and submits each one as a standard REST batch job. If a chunk fails, it can simply be retried.

### VAD boundary detection

```python
MIN_CHUNK_DURATION_S = 25  # seconds before VAD starts listening for end-of-speech

def _is_speech_end(vad: VADIterator, pcm: bytes) -> bool:
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / INT16_MAX
    tensor = torch.from_numpy(samples)
    windows = (tensor[i : i + VAD_WINDOW] for i in range(0, len(tensor) - VAD_WINDOW + 1, VAD_WINDOW))
    return any((r := vad(w)) and "end" in r for w in windows)
```

Silero VAD requires exactly 512 samples per call at 16 kHz. Each incoming frame is processed in 512-sample windows and `True` is returned on the first end-of-speech event. VAD state is reset after each chunk boundary so the next chunk starts fresh.

### Batch API submission

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

## Configuration

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

## Expected Output

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

## Project Structure

```
07-medical-microbatching/
├── python/
│   ├── main.py                    # Main script
│   └── requirements.txt
├── .env.example                   # Environment variable template
└── README.md
```

## Troubleshooting

**"SPEECHMATICS_API_KEY not set"**
- Copy `.env.example` to `.env` and add your key
- Ensure you are running the script from the `python/` directory, or that `.env` is found on the path

**"Failed to start microphone"**
- Ensure `PyAudio` is installed: `pip install PyAudio`
- On Mac you may need `brew install portaudio` first
- On Linux: `sudo apt-get install portaudio19-dev`

**"No audio was recorded"**
- The script exits cleanly if Ctrl+C is pressed before any VAD boundary is detected and no audio is buffered

**"Rate limited"**
- Try reducing the polling rate.

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

**Time to Complete**: 10 minutes
**Difficulty**: Intermediate
**API Mode**: Batch

[Back to Use Cases](../) | [Back to Academy](../../README.md)
