"""
Core infrastructure for the Voice API Explorer.

Audio utilities, WebSocket session runner, and message formatter.
Shared by demos.py and main.py.
"""

import asyncio
import json
import os
import sys
import wave
from pathlib import Path

import pyaudio
import websockets

# ─── Constants ────────────────────────────────────────────────────────────────

DEFAULT_SERVER = "wss://preview.rt.speechmatics.com"
MIC_SAMPLE_RATE = 16000   # Mic recording sample rate (Hz)
MIC_CHUNK_MS = 20         # Mic callback buffer size (ms)
REPLAY_CHUNK_MS = 100     # Replay chunk size for streaming (ms)
PACING = 4.0              # Replay audio at Nx real-time speed
DEBUG = False             # Set via --debug flag from CLI


# ─── Audio Utilities ──────────────────────────────────────────────────────────


def record_audio(sample_rate: int = MIC_SAMPLE_RATE) -> tuple:
    """Record from microphone until Enter is pressed. Returns (pcm, sample_rate).

    Uses PyAudio's callback mode so recording runs in a background thread
    while the main thread blocks on Enter.
    """
    chunk_frames = sample_rate * MIC_CHUNK_MS // 1000
    chunks = []
    recording = True

    def callback(in_data, frame_count, time_info, status):
        if recording:
            chunks.append(in_data)
        return (None, pyaudio.paContinue)

    pa = pyaudio.PyAudio()
    stream = pa.open(
        format=pyaudio.paInt16,
        channels=1,
        rate=sample_rate,
        input=True,
        frames_per_buffer=chunk_frames,
        stream_callback=callback,
    )
    stream.start_stream()

    print("  Recording... speak now, then press Enter to stop.\n")

    try:
        sys.stdin.readline()  # Block until Enter
    except (EOFError, KeyboardInterrupt):
        pass

    recording = False
    stream.stop_stream()
    stream.close()
    pa.terminate()

    pcm = b"".join(chunks)
    duration = len(pcm) / (sample_rate * 2)
    print(f"  Recorded {duration:.1f}s of audio ({sample_rate}Hz, 16-bit mono)")

    if duration < 0.5:
        print("  Warning: Very short recording. Check your microphone is working.")

    return pcm, sample_rate


def read_wav(path: Path) -> tuple:
    """Read a WAV file and return (raw_pcm_bytes, sample_rate).

    Validates that the file is 16-bit mono PCM.
    """
    with wave.open(str(path), "rb") as wf:
        if wf.getsampwidth() != 2:
            raise ValueError(
                f"Expected 16-bit audio, got {wf.getsampwidth() * 8}-bit. "
                "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav"
            )
        if wf.getnchannels() != 1:
            raise ValueError(
                f"Expected mono audio, got {wf.getnchannels()} channels. "
                "Please convert: ffmpeg -i input.wav -acodec pcm_s16le -ac 1 -ar 16000 sample.wav"
            )
        sample_rate = wf.getframerate()
        pcm = wf.readframes(wf.getnframes())

    duration = len(pcm) / (sample_rate * 2)
    print(f"  Audio: {path.name} ({duration:.1f}s, {sample_rate}Hz, 16-bit mono)")
    return pcm, sample_rate


def iter_chunks(pcm: bytes, sample_rate: int, chunk_ms: int = REPLAY_CHUNK_MS):
    """Yield audio chunks of chunk_ms milliseconds."""
    chunk_bytes = sample_rate * 2 * chunk_ms // 1000  # 2 bytes per sample (16-bit)
    for i in range(0, len(pcm), chunk_bytes):
        yield pcm[i : i + chunk_bytes]


# ─── Session Runner ───────────────────────────────────────────────────────────


async def run_session(
    *,
    api_key: str,
    server: str,
    path: str,
    config: dict,
    pcm: bytes,
    sample_rate: int,
    on_message,
    after_audio_fn=None,
):
    """
    Run a complete Voice API WebSocket session.

    Lifecycle:
      1. Connect with Bearer token auth
      2. Send StartRecognition
      3. Wait for RecognitionStarted
      4. Stream audio as binary frames (paced)
      5. Optionally run after_audio_fn(ws) for mid-session commands
      6. Send EndOfStream
      7. Receive messages until EndOfTranscript
    """
    url = f"{server}{path}"
    headers = {"Authorization": f"Bearer {api_key}"}
    messages = []

    recognition_started = asyncio.Event()
    session_ended = asyncio.Event()

    if DEBUG:
        print(f"  [DEBUG] URL: {url}")

    try:
        async with websockets.connect(
            url,
            additional_headers=headers,
            open_timeout=10,
            ping_interval=20,
            ping_timeout=60,
        ) as ws:
            # Send StartRecognition as the first frame
            start_msg = {"message": "StartRecognition", **config}
            if DEBUG:
                print(f"  [DEBUG] Sending: {json.dumps(start_msg, indent=2)}")
            await ws.send(json.dumps(start_msg))

            async def receiver():
                """Receive and dispatch server messages."""
                async for frame in ws:
                    if isinstance(frame, bytes):
                        continue  # Skip unexpected binary frames
                    try:
                        msg = json.loads(frame)
                    except (json.JSONDecodeError, TypeError):
                        continue

                    msg_type = msg.get("message", "")
                    messages.append(msg)

                    if DEBUG:
                        # Show every message type + truncated raw JSON
                        print(f"  [DEBUG] << {msg_type}: {json.dumps(msg)[:200]}")

                    if msg_type == "RecognitionStarted":
                        recognition_started.set()

                    on_message(msg)

                    if msg_type == "EndOfTranscript":
                        session_ended.set()
                        break

            async def sender():
                """Stream audio, run mid-session actions, send EndOfStream."""
                # Wait for RecognitionStarted before streaming audio
                try:
                    await asyncio.wait_for(recognition_started.wait(), timeout=10.0)
                except asyncio.TimeoutError:
                    print("  [Timeout] RecognitionStarted not received within 10s")
                    return

                # Stream audio chunks at paced rate
                chunk_delay = (REPLAY_CHUNK_MS / 1000) / PACING
                for chunk in iter_chunks(pcm, sample_rate):
                    await ws.send(chunk)
                    await asyncio.sleep(chunk_delay)

                # Mid-session actions (ForceEOU, UpdateSpeakerFocus, etc.)
                if after_audio_fn:
                    await after_audio_fn(ws)

                # Signal end of audio
                eos = {"message": "EndOfStream", "last_seq_no": 0}
                await ws.send(json.dumps(eos))

            await asyncio.gather(receiver(), sender())

    except websockets.exceptions.ConnectionClosedError as e:
        print(f"  [ConnectionClosed] code={e.code} reason={e.reason}")
    except websockets.exceptions.InvalidStatusCode as e:
        print(f"  [ConnectionFailed] HTTP {e.status_code}")
        if e.status_code == 401:
            print("  Check your SPEECHMATICS_API_KEY is valid.")
    except OSError as e:
        print(f"  [NetworkError] {e}")

    return messages


# ─── Message Formatter ────────────────────────────────────────────────────────


# ANSI colour codes
class C:
    RESET   = "\033[0m"
    BOLD    = "\033[1m"
    DIM     = "\033[2m"
    # Foreground
    GREEN   = "\033[32m"     # Finals, Segments, Translations
    YELLOW  = "\033[33m"     # Partials
    CYAN    = "\033[36m"     # Speaker events, Turn events
    MAGENTA = "\033[35m"     # Metrics
    RED     = "\033[31m"     # Errors
    ORANGE  = "\033[38;5;208m"  # Warnings
    BLUE    = "\033[34m"     # Session lifecycle
    WHITE   = "\033[37m"     # Optional / debug messages


# Enable ANSI escape processing on Windows
if sys.platform == "win32":
    os.system("")


def _fmt(v):
    """Format a numeric value to 2 decimal places, or return as-is if not a number."""
    return f"{v:.2f}" if isinstance(v, (int, float)) else str(v)


# Optional message types — only shown when the demo explicitly opts in
OPTIONAL_MSG_TYPES = {
    "AudioAdded", "SpeechStarted", "SpeechEnded",
    "EndOfTurnPrediction", "SmartTurnPrediction", "Diagnostics",
}


def print_msg(msg: dict, indent: int = 4, show_optional: bool = False):
    """Pretty-print a Voice API server message.

    Optional message types (AudioAdded, SpeechStarted, etc.) are suppressed
    unless show_optional=True — the server may forward them even without
    explicit message_control.include.
    """
    p = " " * indent
    mt = msg.get("message", "unknown")

    if not show_optional and mt in OPTIONAL_MSG_TYPES:
        return

    if mt == "RecognitionStarted":
        sid = msg.get("id", "?")[:20]
        lang = msg.get("language_pack_info", {}).get("language_description", "?")
        ver = msg.get("orchestrator_version", "")
        print(f"{p}{C.BLUE}{C.BOLD}[RecognitionStarted]{C.RESET}{C.BLUE} session={sid}... lang={lang}{C.RESET}")
        if ver:
            print(f"{p}{C.BLUE}  orchestrator: {ver}{C.RESET}")

    elif mt == "AddPartialTranscript":
        text = msg.get("metadata", {}).get("transcript", "")
        if text.strip():
            print(f"{p}{C.YELLOW}[Partial]     {text}{C.RESET}")

    elif mt == "AddTranscript":
        text = msg.get("metadata", {}).get("transcript", "")
        if text.strip():
            results = msg.get("results", [])
            words = [r for r in results if r.get("type") == "word"]
            if words:
                confs = [w["alternatives"][0]["confidence"] for w in words]
                avg = sum(confs) / len(confs)
                print(f"{p}{C.GREEN}{C.BOLD}[Final]       {text}  (avg confidence: {avg:.2f}){C.RESET}")
            else:
                print(f"{p}{C.GREEN}{C.BOLD}[Final]       {text}{C.RESET}")

    elif mt == "AddPartialTranslation":
        lang = msg.get("language", "?")
        text = msg.get("metadata", {}).get("transcript", "")
        if not text:
            results = msg.get("results", [])
            text = " ".join(r.get("content", "") for r in results).strip()
        if text.strip():
            print(f"{p}{C.YELLOW}[PartialTr:{lang}] {text}{C.RESET}")
        else:
            print(f"{p}{C.YELLOW}[PartialTr:{lang}] (raw: {json.dumps(msg)[:120]}){C.RESET}")

    elif mt == "AddTranslation":
        lang = msg.get("language", "?")
        text = msg.get("metadata", {}).get("transcript", "")
        if not text:
            results = msg.get("results", [])
            text = " ".join(r.get("content", "") for r in results).strip()
        if text.strip():
            print(f"{p}{C.GREEN}{C.BOLD}[Translation:{lang}] {text}{C.RESET}")
        else:
            print(f"{p}{C.GREEN}{C.BOLD}[Translation:{lang}] (raw: {json.dumps(msg)[:120]}){C.RESET}")

    elif mt == "AddPartialSegment":
        for seg in msg.get("segments", []):
            text = seg.get("text", "")
            if text.strip():
                spk = seg.get("speaker_id", "?")
                ann = seg.get("annotation", [])
                ann_s = f"  [{', '.join(ann)}]" if ann else ""
                print(f"{p}{C.YELLOW}[PartialSeg]  {spk}: {text}{ann_s}{C.RESET}")

    elif mt == "AddSegment":
        for seg in msg.get("segments", []):
            text = seg.get("text", "")
            spk = seg.get("speaker_id", "?")
            ann = seg.get("annotation", [])
            eou = seg.get("is_eou", False)
            meta = seg.get("metadata", {})
            t0, t1 = meta.get("start_time", 0), meta.get("end_time", 0)
            ann_s = f"  {C.DIM}[{', '.join(ann)}]{C.RESET}" if ann else ""
            eou_s = f" {C.CYAN}(EOU){C.RESET}" if eou else ""
            print(f"{p}{C.GREEN}{C.BOLD}[Segment]     {spk}: {text} ({t0:.2f}-{t1:.2f}s){C.RESET}{ann_s}{eou_s}")

    elif mt == "SpeakerStarted":
        spk = msg.get("speaker_id", "?")
        t = msg.get("metadata", {}).get("start_time", msg.get("time", "?"))
        print(f"{p}{C.CYAN}[SpeakerStarted] {spk} at {_fmt(t)}s{C.RESET}")

    elif mt == "SpeakerEnded":
        spk = msg.get("speaker_id", "?")
        t = msg.get("metadata", {}).get("end_time", msg.get("time", "?"))
        print(f"{p}{C.CYAN}[SpeakerEnded]   {spk} at {_fmt(t)}s{C.RESET}")

    elif mt == "StartOfTurn":
        print(f"{p}{C.CYAN}{C.BOLD}[StartOfTurn]  turn_id={msg.get('turn_id', '?')}{C.RESET}")

    elif mt == "EndOfTurn":
        print(f"{p}{C.CYAN}{C.BOLD}[EndOfTurn]    turn_id={msg.get('turn_id', '?')}{C.RESET}")

    elif mt == "EndOfUtterance":
        meta = msg.get("metadata", {})
        print(f"{p}{C.CYAN}[EndOfUtterance] {_fmt(meta.get('start_time', '?'))}s - {_fmt(meta.get('end_time', '?'))}s{C.RESET}")

    elif mt == "SessionMetrics":
        total = msg.get("total_time_str", msg.get("total_time", "?"))
        proc = msg.get("processing_time", "?")
        byt = msg.get("total_bytes", "?")
        print(f"{p}{C.MAGENTA}[SessionMetrics]  time={total} processing={proc}s bytes={byt}{C.RESET}")

    elif mt == "SpeakerMetrics":
        for spk in msg.get("speakers", []):
            sid = spk.get("speaker_id", "?")
            wc = spk.get("word_count", 0)
            vol = spk.get("volume", 0)
            last = spk.get("last_heard", 0)
            print(f"{p}{C.MAGENTA}[SpeakerMetrics]  {sid}: words={wc} vol={vol:.1f} last={last:.2f}s{C.RESET}")

    elif mt == "SpeakersResult":
        speakers = msg.get("speakers", msg)
        print(f"{p}{C.MAGENTA}[SpeakersResult]  {json.dumps(speakers)[:200]}{C.RESET}")

    elif mt == "AudioAdded":
        seq = msg.get("seq_no", "?")
        print(f"{p}{C.DIM}[AudioAdded]   seq_no={seq}{C.RESET}")

    elif mt == "SpeechStarted":
        t = msg.get("metadata", {}).get("start_time", "?")
        prob = msg.get("probability", "?")
        print(f"{p}{C.WHITE}[SpeechStarted]  at {_fmt(t)}s  probability={prob}{C.RESET}")

    elif mt == "SpeechEnded":
        meta = msg.get("metadata", {})
        prob = msg.get("probability", "?")
        dur = msg.get("transition_duration_ms", "?")
        print(
            f"{p}{C.WHITE}[SpeechEnded]    {_fmt(meta.get('start_time', '?'))}-{_fmt(meta.get('end_time', '?'))}s"
            f"  prob={prob}  transition={dur}ms{C.RESET}"
        )

    elif mt == "EndOfTurnPrediction":
        wait = msg.get("predicted_wait", "?")
        print(f"{p}{C.WHITE}[EndOfTurnPrediction] predicted_wait={_fmt(wait)}s{C.RESET}")

    elif mt == "SmartTurnPrediction":
        print(f"{p}{C.WHITE}[SmartTurnPrediction] {json.dumps(msg)[:140]}{C.RESET}")

    elif mt == "AudioEventStarted":
        etype = msg.get("type", msg.get("event", "?"))
        print(f"{p}{C.CYAN}[AudioEventStarted] type={etype}{C.RESET}")

    elif mt == "AudioEventEnded":
        etype = msg.get("type", msg.get("event", "?"))
        print(f"{p}{C.CYAN}[AudioEventEnded]   type={etype}{C.RESET}")

    elif mt == "Info":
        itype = msg.get("type", "")
        reason = msg.get("reason", "")
        extra = ""
        if msg.get("quality"):
            extra = f" quality={msg['quality']}"
        print(f"{p}{C.BLUE}[Info:{itype}] {reason}{extra}{C.RESET}")

    elif mt == "Warning":
        print(f"{p}{C.ORANGE}{C.BOLD}[Warning] {msg.get('reason', msg.get('type', ''))}{C.RESET}")

    elif mt == "Error":
        print(f"{p}{C.RED}{C.BOLD}[Error] {msg.get('reason', msg.get('type', json.dumps(msg)))}{C.RESET}")

    elif mt == "EndOfTranscript":
        print(f"{p}{C.BLUE}{C.BOLD}[EndOfTranscript] Session complete.{C.RESET}")

    elif mt == "Diagnostics":
        print(f"{p}{C.DIM}[Diagnostics] {json.dumps(msg)[:140]}{C.RESET}")

    else:
        print(f"{p}{C.DIM}[{mt}] {json.dumps(msg)[:140]}{C.RESET}")


# ─── Helpers ──────────────────────────────────────────────────────────────────


def header(title: str):
    print(f"\n{'=' * 80}")
    print(f"  {title}")
    print(f"{'=' * 80}\n")


def subheader(title: str):
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


def audio_format_block(sample_rate: int) -> dict:
    """Standard audio_format config block for raw PCM."""
    return {
        "type": "raw",
        "encoding": "pcm_s16le",
        "sample_rate": sample_rate,
    }
