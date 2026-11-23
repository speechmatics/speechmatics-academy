#!/usr/bin/env python3
"""
Phone Voice Agent - Vobiz + Speechmatics

A phone voice agent built on Speechmatics agent STT and Speechmatics Text to
Speech, with any OpenAI-compatible LLM (Gemini by default).

    caller --PSTN--> Vobiz <Stream bidirectional> --WebSocket--> this server
                                                                    |
           Speechmatics agent STT (Linden 1, server-side turn detection)
                                                                    | EndOfTurn
                                                     LLM (streamed, OpenAI-compatible)
                                                                    | one sentence at a time
           Speechmatics TTS (HTTPS, 16 kHz PCM, streamed) --playAudio--> caller

Run `python main.py`, then point a Vobiz number or an outbound call at the
answer URL it prints (see dial.py).
"""

import asyncio
import base64
import json
import os
import re
import secrets
import sys
import time
from html import escape
from pathlib import Path

import aiohttp
from aiohttp import web
from dotenv import load_dotenv

load_dotenv()

SM_API_KEY = os.getenv("SPEECHMATICS_API_KEY")
SM_STT_URL = os.getenv("SM_STT_URL", "wss://eu2.rt.speechmatics.com/v2/agent")
SM_TTS_URL = "https://preview.tts.speechmatics.com/generate/{voice}?output_format=pcm_16000"
SM_VOICE = os.getenv("SM_VOICE", "sarah")  # sarah, theo (UK English) - megan, jack (US English)
LANGUAGE = os.getenv("SM_LANGUAGE", "en")

# Any OpenAI-compatible chat completions endpoint. The default is Gemini.
LLM_URL = (
    os.getenv("LLM_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai").rstrip("/")
    + "/chat/completions"
)
LLM_API_KEY = os.getenv("LLM_API_KEY") or os.getenv("GEMINI_API_KEY")
LLM_MODEL = os.getenv("LLM_MODEL", "gemini-3.1-flash-lite")
# Model "thinking" delays the first word; a phone agent should answer at once.
# Set LLM_REASONING_EFFORT to an empty value for models that reject the field.
LLM_REASONING_EFFORT = os.getenv("LLM_REASONING_EFFORT", "minimal")

PUBLIC_URL = (os.getenv("PUBLIC_URL") or "").rstrip("/")
PORT = int(os.getenv("PORT", "8765"))
# A random path segment keeps the answer URL and the audio WebSocket private to
# this run: the Vobiz audio WebSocket itself carries no signature.
PATH_TOKEN = os.getenv("PATH_TOKEN") or secrets.token_urlsafe(16)

RATE = 16000
FRAME = 640  # 20 ms of 16-bit mono PCM at 16 kHz
CHUNK = FRAME * 3  # 60 ms per playAudio message keeps barge-in responsive

HANGUP_TOKEN = "[END_CALL]"
PROMPT_FILE = Path(__file__).resolve().parent.parent / "assets" / "agent.md"
GREETING = (
    "Hi, I'm Vee, the Vobiz voice assistant. I'm listening with Speechmatics speech to text "
    "and talking with Speechmatics text to speech. What would you like to know?"
)

SENTENCE_END = re.compile(r"(.+?[.!?])(\s+|$)", re.S)


def log(*parts: object) -> None:
    print(time.strftime("%H:%M:%S"), *parts, flush=True)


def answer_xml() -> str:
    """VobizXML that connects the call to this server over a bidirectional stream."""
    stream_url = f"{PUBLIC_URL.replace('https://', 'wss://')}/ws/{PATH_TOKEN}"
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<Response>\n"
        f'  <Stream bidirectional="true" keepCallAlive="true" audioTrack="inbound" '
        f'contentType="audio/x-l16;rate={RATE}">{escape(stream_url)}</Stream>\n'
        "</Response>\n"
    )


def system_prompt() -> str:
    return PROMPT_FILE.read_text(encoding="utf-8").replace("{HANGUP_TOKEN}", HANGUP_TOKEN)


class Call:
    """One phone call: Vobiz audio in, agent STT, LLM, TTS, Vobiz audio out."""

    def __init__(self, vobiz: web.WebSocketResponse, http: aiohttp.ClientSession, prompt: str):
        self.vobiz = vobiz
        self.http = http
        self.stt: aiohttp.ClientWebSocketResponse | None = None
        self.stt_reader: asyncio.Task | None = None
        self.stream_id: str | None = None
        self.history: list[dict] = [{"role": "system", "content": prompt}]
        self.turn_text: list[str] = []
        self.reply_task: asyncio.Task | None = None
        self.speaking = False
        self.hangup_after_speech = False
        self.seq = 0
        self.turn_ended_at = 0.0

    # ---------- Vobiz side ----------
    async def send_vobiz(self, msg: dict) -> None:
        if not self.vobiz.closed:
            await self.vobiz.send_str(json.dumps(msg))

    async def play_pcm(self, pcm: bytes) -> None:
        for i in range(0, len(pcm), CHUNK):
            await self.send_vobiz(
                {
                    "event": "playAudio",
                    "media": {
                        "contentType": "audio/x-l16",
                        "sampleRate": RATE,
                        "payload": base64.b64encode(pcm[i : i + CHUNK]).decode(),
                    },
                }
            )

    async def barge_in(self) -> None:
        """The caller started talking: stop the reply and flush queued audio."""
        if self.reply_task and not self.reply_task.done():
            self.reply_task.cancel()
        if self.speaking:
            log("BARGE-IN  caller spoke over the agent, clearing audio")
            await self.send_vobiz({"event": "clearAudio", "streamId": self.stream_id})
            self.speaking = False

    # ---------- Speechmatics agent STT ----------
    async def start_stt(self) -> None:
        self.stt = await self.http.ws_connect(
            SM_STT_URL, headers={"Authorization": f"Bearer {SM_API_KEY}"}, heartbeat=20
        )
        await self.stt.send_str(
            json.dumps(
                {
                    "message": "StartRecognition",
                    "audio_format": {"type": "raw", "encoding": "pcm_s16le", "sample_rate": RATE},
                    "transcription_config": {"language": LANGUAGE, "model": "linden-1", "enable_partials": True},
                }
            )
        )
        self.stt_reader = asyncio.create_task(self.read_stt())

    async def read_stt(self) -> None:
        async for msg in self.stt:
            if msg.type != aiohttp.WSMsgType.TEXT:
                continue
            data = json.loads(msg.data)
            kind = data.get("message")
            if kind == "RecognitionStarted":
                log("STT       Speechmatics session started", data.get("id"))
            elif kind in ("StartOfTurn", "SpeechStarted"):
                await self.barge_in()
            elif kind == "AddSegment":
                text = data["segment"]["transcript"].strip()
                if text:
                    self.turn_text.append(text)
            elif kind == "EndOfTurn":
                text = " ".join(self.turn_text).strip()
                self.turn_text = []
                if text:
                    self.turn_ended_at = time.time()
                    log(f"CALLER    {text}")
                    self.reply_task = asyncio.create_task(self.reply(text))
            elif kind in ("Error", "Warning"):
                log("STT      ", msg.data[:300])

    async def send_audio(self, pcm: bytes) -> None:
        if self.stt and not self.stt.closed:
            await self.stt.send_bytes(pcm)
            self.seq += 1

    # ---------- LLM + Speechmatics TTS ----------
    async def llm_sentences(self):
        """Stream the LLM reply and yield it one sentence at a time."""
        body = {"model": LLM_MODEL, "messages": self.history, "stream": True, "temperature": 0.6, "max_tokens": 200}
        if LLM_REASONING_EFFORT:
            body["reasoning_effort"] = LLM_REASONING_EFFORT
        buf = ""
        async with self.http.post(LLM_URL, json=body, headers={"Authorization": f"Bearer {LLM_API_KEY}"}) as r:
            if r.status != 200:
                log("LLM       error", r.status, (await r.text())[:300])
                return
            async for raw in r.content:
                line = raw.decode().strip()
                if not line.startswith("data:") or line == "data: [DONE]":
                    continue
                chunk = json.loads(line[5:])
                if not chunk.get("choices"):
                    continue
                buf += chunk["choices"][0].get("delta", {}).get("content") or ""
                while m := SENTENCE_END.match(buf):
                    yield m.group(1).strip()
                    buf = buf[m.end() :]
        if buf.strip():
            yield buf.strip()

    async def speak(self, text: str) -> None:
        """Speechmatics TTS: stream 16 kHz PCM straight into playAudio."""
        first = True
        carry = b""
        async with self.http.post(
            SM_TTS_URL.format(voice=SM_VOICE), json={"text": text}, headers={"Authorization": f"Bearer {SM_API_KEY}"}
        ) as r:
            if r.status != 200:
                log("TTS       error", r.status, (await r.text())[:300])
                return
            self.speaking = True
            async for chunk in r.content.iter_chunked(CHUNK):
                if first and self.turn_ended_at:
                    elapsed_ms = (time.time() - self.turn_ended_at) * 1000
                    log(f"LATENCY   end of caller turn -> first agent audio: {elapsed_ms:.0f} ms")
                    self.turn_ended_at = 0.0
                first = False
                chunk = carry + chunk
                cut = len(chunk) - (len(chunk) % 2)  # send whole 16-bit samples only
                chunk, carry = chunk[:cut], chunk[cut:]
                await self.play_pcm(chunk)

    async def reply(self, user_text: str) -> None:
        self.history.append({"role": "user", "content": user_text})
        said = []
        try:
            async for sentence in self.llm_sentences():
                end = HANGUP_TOKEN in sentence
                sentence = sentence.replace(HANGUP_TOKEN, "").strip()
                if sentence:
                    log(f"AGENT     {sentence}")
                    said.append(sentence)
                    await self.speak(sentence)
                if end:
                    self.hangup_after_speech = True
            # Vobiz answers with playedStream once everything queued so far has played.
            await self.send_vobiz(
                {"event": "checkpoint", "streamId": self.stream_id, "name": f"turn-{len(self.history)}"}
            )
        except asyncio.CancelledError:
            said.append("(interrupted)")
            raise
        finally:
            if said:
                self.history.append({"role": "assistant", "content": " ".join(said)})

    async def greet(self) -> None:
        log(f"AGENT     {GREETING}")
        self.history.append({"role": "assistant", "content": GREETING})
        await self.speak(GREETING)
        await self.send_vobiz({"event": "checkpoint", "streamId": self.stream_id, "name": "greeting"})

    # ---------- main loop ----------
    async def run(self) -> None:
        try:
            async for msg in self.vobiz:
                if msg.type != aiohttp.WSMsgType.TEXT:
                    continue
                data = json.loads(msg.data)
                event = data.get("event")
                if event == "media":
                    await self.send_audio(base64.b64decode(data["media"]["payload"]))
                elif event == "start":
                    start = data["start"]
                    self.stream_id = start.get("streamId")
                    log(f"CALL      started call={start.get('callId')} format={start.get('mediaFormat')}")
                    try:
                        await self.start_stt()
                    except aiohttp.ClientError as e:
                        log(f"STT       could not connect to Speechmatics: {e}")
                        break
                    self.reply_task = asyncio.create_task(self.greet())
                elif event == "playedStream":
                    self.speaking = False
                    if self.hangup_after_speech:
                        log("CALL      goodbye played, ending the call")
                        await self.send_vobiz({"event": "stop", "streamId": self.stream_id})
                elif event == "dtmf":
                    log(f"DTMF      caller pressed {data['dtmf']['digit']}")
        finally:
            # Vobiz sends no stop event: the socket closing is the end of the call.
            await self.close()

    async def close(self) -> None:
        if self.reply_task:
            self.reply_task.cancel()
        if self.stt and not self.stt.closed:
            try:
                await self.stt.send_str(json.dumps({"message": "EndOfStream", "last_seq_no": self.seq}))
            except (aiohttp.ClientError, ConnectionError):
                pass
            finally:
                await self.stt.close()
        if self.stt_reader:
            self.stt_reader.cancel()
        log("CALL      ended")


async def answer(_request: web.Request) -> web.Response:
    log("HTTP      answer URL fetched")
    return web.Response(text=answer_xml(), content_type="application/xml")


async def hangup(request: web.Request) -> web.Response:
    form = await request.post() if request.can_read_body else request.query
    log(f"HTTP      hangup cause={form.get('HangupCause')} duration={form.get('Duration')}")
    return web.Response(text="OK")


async def media_stream(request: web.Request) -> web.WebSocketResponse:
    sock = web.WebSocketResponse()
    await sock.prepare(request)
    await Call(sock, request.app["http"], request.app["prompt"]).run()
    return sock


async def on_startup(app: web.Application) -> None:
    app["http"] = aiohttp.ClientSession()


async def on_cleanup(app: web.Application) -> None:
    await app["http"].close()


def make_app() -> web.Application:
    app = web.Application()
    app["prompt"] = system_prompt()
    app.router.add_route("*", f"/answer/{PATH_TOKEN}", answer)
    app.router.add_route("*", f"/hangup/{PATH_TOKEN}", hangup)
    app.router.add_get(f"/ws/{PATH_TOKEN}", media_stream)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    return app


def check_config() -> None:
    missing = [
        name
        for name, value in (
            ("SPEECHMATICS_API_KEY", SM_API_KEY),
            ("GEMINI_API_KEY or LLM_API_KEY", LLM_API_KEY),
            ("PUBLIC_URL", PUBLIC_URL),
        )
        if not value
    ]
    if missing:
        sys.exit(f"Missing required settings in .env: {', '.join(missing)}")
    if not PUBLIC_URL.startswith("https://"):
        sys.exit(
            "PUBLIC_URL must start with https:// - Vobiz fetches the answer URL over HTTPS and streams over wss://"
        )


if __name__ == "__main__":
    check_config()
    log(f"Answer URL: {PUBLIC_URL}/answer/{PATH_TOKEN}")
    log(f"Hangup URL: {PUBLIC_URL}/hangup/{PATH_TOKEN}")
    log(f"Voice: {SM_VOICE}  LLM: {LLM_MODEL}  Listening on http://127.0.0.1:{PORT}")
    web.run_app(make_app(), host="127.0.0.1", port=PORT, print=None)
