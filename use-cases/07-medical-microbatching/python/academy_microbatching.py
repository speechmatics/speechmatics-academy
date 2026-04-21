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
import wave

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

SAMPLE_RATE: int = 16000
MIN_CHUNK_DURATION_S: int = 25
MIN_BYTES: int = SAMPLE_RATE * MIN_CHUNK_DURATION_S * 2
READ_SIZE: int = 4096
VAD_WINDOW: int = 512  # samples required by Silero VAD at 16 kHz

TRANSCRIPTION_CONFIG = TranscriptionConfig(
    language="en",
    operating_point=OperatingPoint.STANDARD,
)

POLLING_INTERVAL = 2.0

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


# -- VAD ----------------------------------------------------------------------

def _load_vad() -> VADIterator:
    """Load Silero VAD and return a ready-to-use VADIterator."""
    return VADIterator(load_silero_vad(), sampling_rate=SAMPLE_RATE)


def _is_speech_end(vad: VADIterator, pcm: bytes) -> bool:
    """Return True if end-of-speech is detected anywhere in pcm.

    Processes audio in 512-sample windows as required by Silero VAD.
    Any incomplete trailing window is discarded.
    """
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    tensor = torch.from_numpy(samples)
    for i in range(0, len(tensor) - VAD_WINDOW + 1, VAD_WINDOW):
        result = vad(tensor[i : i + VAD_WINDOW])
        if result and "end" in result:
            return True
    return False


# -- Transcription ------------------------------------------------------------

def _pcm_to_wav(raw_pcm: bytes) -> io.BytesIO:
    """Wrap raw int16 PCM bytes in an in-memory WAV container."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw_pcm)
    buf.seek(0)
    buf.name = "chunk.wav"
    return buf


def _submit_chunk(client: AsyncClient, pcm: bytes) -> asyncio.Task:
    """Wrap pcm in a WAV container and fire off a transcribe task."""
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
) -> list[asyncio.Task]:
    """Record audio and fire a transcribe task at each VAD speech boundary."""
    tasks: list[asyncio.Task] = []
    buffer = bytearray()
    chunk_index = 0

    logger.info("Audio capture started. Press Ctrl+C to stop.")

    try:
        while True:
            data = await mic.read(READ_SIZE)
            buffer.extend(data)

            if _is_speech_end(vad, data) and len(buffer) >= MIN_BYTES:
                logger.info("Chunk %d: VAD boundary detected. Submitting ...", chunk_index)
                tasks.append(_submit_chunk(client, bytes(buffer)))
                buffer.clear()
                vad.reset_states()
                chunk_index += 1

    except (KeyboardInterrupt, asyncio.CancelledError):
        logger.info("Recording stopped.")

    if buffer:
        logger.info("Submitting final partial chunk %d ...", chunk_index)
        tasks.append(_submit_chunk(client, bytes(buffer)))

    return tasks


# -- Entry point --------------------------------------------------------------

async def main() -> None:
    logger.info("Loading Silero VAD model ...")
    vad = _load_vad()

    mic = Microphone(sample_rate=SAMPLE_RATE)
    if not mic.start():
        logger.error("Failed to start microphone. Is pyaudio installed?")
        return

    try:
        async with AsyncClient(api_key=api_key) as client:
            tasks = await capture_and_transcribe(client, mic, vad)

            if not tasks:
                logger.warning("No audio was recorded.")
                return

            logger.info("%d chunk(s) submitted. Waiting for transcripts ...", len(tasks))
            results = await asyncio.gather(*tasks, return_exceptions=True)
    finally:
        mic.stop()

    texts = []
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            logger.error("Chunk %d failed: %s", i, result)
        else:
            texts.append(result.transcript_text)

    print("\n--- TRANSCRIPT ---\n")
    print("\n\n".join(t.strip() for t in texts if t.strip()))


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
