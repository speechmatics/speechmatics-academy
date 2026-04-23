"""
Records audio from the default microphone and transcribes each chunk
concurrently via the Speechmatics Batch API, using Silero VAD to find
natural speech boundaries between chunks.

Once a chunk reaches 25 seconds, Silero VAD listens for end-of-speech.
When detected, the chunk is submitted and a new one begins.  Press
Ctrl+C to stop; any partial final chunk is submitted, all outstanding
jobs are awaited, and the full transcript is printed to stdout in order.

Requirements:
    pip install silero-vad torch pyaudio speechmatics-batch speechmatics-rt
"""

import asyncio
import io
import logging
import os
import time
import wave
from datetime import datetime
from typing import NamedTuple

import numpy as np
import torch
from dotenv import load_dotenv
from silero_vad import VADIterator, load_silero_vad

from speechmatics.batch import AsyncClient, OperatingPoint, TranscriptionConfig
from speechmatics.rt import Microphone

load_dotenv()

API_KEY = os.getenv("SPEECHMATICS_API_KEY")
if not API_KEY:
    raise SystemExit("Error: SPEECHMATICS_API_KEY not set. Please set it in your .env file")

# -- Audio constants ----------------------------------------------------------

SAMPLE_RATE: int = 16000
BYTES_PER_SAMPLE: int = 2  # 16-bit PCM
MIN_CHUNK_DURATION_S: int = 25
MIN_CHUNK_BYTES: int = SAMPLE_RATE * MIN_CHUNK_DURATION_S * BYTES_PER_SAMPLE
READ_SIZE: int = 4096
VAD_WINDOW: int = 512  # samples per Silero VAD frame at 16 kHz
INT16_MAX: float = 32768.0  # normalises int16 PCM to [-1, 1]

# -- Speechmatics config ------------------------------------------------------

TRANSCRIPTION_CONFIG = TranscriptionConfig(
    language="en",
    operating_point=OperatingPoint.ENHANCED,
)

POLLING_INTERVAL: float = 2.0

# -- Logging ------------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


# -- Data types ---------------------------------------------------------------


class Chunk(NamedTuple):
    """A submitted transcription task paired with its recording window."""

    task: asyncio.Task
    started_at: float  # wall time when this chunk's recording began
    submitted_at: float  # wall time when the chunk was dispatched to the API


# -- VAD ----------------------------------------------------------------------


def _is_speech_end(vad: VADIterator, pcm: bytes) -> bool:
    """Return True if end-of-speech is detected anywhere in *pcm*."""
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / INT16_MAX
    tensor = torch.from_numpy(samples)
    windows = (tensor[i : i + VAD_WINDOW] for i in range(0, len(tensor) - VAD_WINDOW + 1, VAD_WINDOW))
    return any((r := vad(w)) and "end" in r for w in windows)


# -- Transcription ------------------------------------------------------------


def _pcm_to_wav(raw_pcm: bytes) -> io.BytesIO:
    """Wrap raw int16 PCM bytes in an in-memory WAV container."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(BYTES_PER_SAMPLE)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw_pcm)
    buf.seek(0)
    buf.name = "chunk.wav"
    return buf


def _submit_chunk(client: AsyncClient, pcm: bytes) -> asyncio.Task:
    """Wrap *pcm* in a WAV container and fire off a transcription task."""
    return asyncio.create_task(
        client.transcribe(
            _pcm_to_wav(pcm),
            transcription_config=TRANSCRIPTION_CONFIG,
            polling_interval=POLLING_INTERVAL,
        )
    )


# -- Capture ------------------------------------------------------------------


async def capture_and_transcribe(
    client: AsyncClient,
    mic: Microphone,
    vad: VADIterator,
) -> list[Chunk]:
    """Record audio and dispatch a transcription task at each VAD boundary."""
    chunks: list[Chunk] = []
    buffer = bytearray()
    chunk_start = time.time()

    logger.info("Audio capture started. Press Ctrl+C to stop.")

    try:
        while True:
            data = await mic.read(READ_SIZE)
            buffer.extend(data)

            if _is_speech_end(vad, data) and len(buffer) >= MIN_CHUNK_BYTES:
                submitted_at = time.time()
                logger.info("Chunk %d: VAD boundary — submitting ...", len(chunks))
                chunks.append(Chunk(_submit_chunk(client, bytes(buffer)), chunk_start, submitted_at))
                buffer.clear()
                vad.reset_states()
                chunk_start = submitted_at

    except (KeyboardInterrupt, asyncio.CancelledError):
        logger.info("Recording stopped.")

    if buffer:
        logger.info("Submitting final partial chunk %d ...", len(chunks))
        chunks.append(Chunk(_submit_chunk(client, bytes(buffer)), chunk_start, time.time()))

    return chunks


# -- Output -------------------------------------------------------------------


def _print_chunk(i: int, chunk: Chunk, text: str) -> None:
    duration = chunk.submitted_at - chunk.started_at
    t_start = datetime.fromtimestamp(chunk.started_at).strftime("%H:%M:%S")
    t_end = datetime.fromtimestamp(chunk.submitted_at).strftime("%H:%M:%S")
    print(f"[Chunk {i} | {t_start} → {t_end} ({duration:.0f}s)]")
    if text:
        print(text)
    print()


# -- Entry point -------------------------------------------------------------


async def main() -> None:
    logger.info("Loading Silero VAD model ...")
    vad = VADIterator(load_silero_vad(), sampling_rate=SAMPLE_RATE)

    mic = Microphone(sample_rate=SAMPLE_RATE)
    if not mic.start():
        logger.error("Failed to start microphone. Is pyaudio installed?")
        return

    try:
        async with AsyncClient(api_key=API_KEY) as client:
            chunks = await capture_and_transcribe(client, mic, vad)

            if not chunks:
                logger.warning("No audio was recorded.")
                return

            logger.info("%d chunk(s) submitted. Waiting for transcripts ...", len(chunks))
            results = await asyncio.gather(*[c.task for c in chunks], return_exceptions=True)
    finally:
        mic.stop()

    print("\n--- TRANSCRIPT ---\n")
    for i, (chunk, result) in enumerate(zip(chunks, results)):
        if isinstance(result, Exception):
            logger.error("Chunk %d failed: %s", i, result)
            _print_chunk(i, chunk, f"ERROR: {result}")
        else:
            text = "\n".join(line.removeprefix("SPEAKER UU: ") for line in result.transcript_text.splitlines())
            _print_chunk(i, chunk, text.strip())


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
