#!/usr/bin/env python3
"""
Phone Voice Agent - Vobiz + Speechmatics

A phone voice agent built on Speechmatics agent STT and Speechmatics Text to
Speech, with any OpenAI-compatible LLM (Gemini by default).

    caller --PSTN--> Vobiz <Stream bidirectional> --WebSocket--> this server
                                                                    |
           Speechmatics agent STT (Linden 1, service-side turn detection)
                                                                    | EndOfTurn
                                                     LLM (streamed, OpenAI-compatible)
                                                                    | one sentence at a time
           Speechmatics TTS (16 kHz PCM, streamed) --playAudio--> caller

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

from speechmatics import tts
from speechmatics.agent_stt import AgentSttAsyncClient, AuthenticationError, ServerMessageType, TranscriptionConfig

load_dotenv()

SM_API_KEY = os.getenv("SPEECHMATICS_API_KEY")
# Optional: the agent STT SDK defaults to the EU endpoint and appends /agent itself.
SM_RT_URL = os.getenv("SPEECHMATICS_RT_URL")
SM_VOICE = tts.Voice(os.getenv("SM_VOICE", "sarah"))  # sarah, theo (UK English) - megan, jack (US English)
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

# Each call holds a paid agent STT session and LLM and TTS requests, so cap both
# how many calls run at once and how long one can last.
MAX_CALLS = int(os.getenv("MAX_CALLS", "5"))
MAX_CALL_SECONDS = int(os.getenv("MAX_CALL_SECONDS", "600"))

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
    """Print a timestamped log line."""
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
    """Load the agent's instructions from assets/agent.md."""
    return PROMPT_FILE.read_text(encoding="utf-8").replace("{HANGUP_TOKEN}", HANGUP_TOKEN)


class Call:
    """One phone call: Vobiz audio in, agent STT, LLM, TTS, Vobiz audio out."""

    def __init__(self, vobiz: web.WebSocketResponse, app: web.Application):
        self.vobiz = vobiz
        self.http: aiohttp.ClientSession = app["http"]
        self.tts: tts.AsyncClient = app["tts"]
        self.stt: AgentSttAsyncClient | None = None
        self.stream_id: str | None = None
        self.history: list[dict] = [{"role": "system", "content": app["prompt"]}]
        self.turn_text: list[str] = []
        self.reply_task: asyncio.Task | None = None
        self.tasks: set[asyncio.Task] = set()
        self.speaking = False
        self.hangup_after_speech = False
        self.turn_ended_at = 0.0

    def spawn(self, coro) -> asyncio.Task:
        """Run a coroutine in the background and keep a reference until it finishes."""
        task = asyncio.create_task(coro)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        return task

    # ---------- Vobiz side ----------
    async def send_vobiz(self, msg: dict) -> None:
        """Send one JSON event to Vobiz if the call is still connected."""
        if not self.vobiz.closed:
            await self.vobiz.send_str(json.dumps(msg))

    async def play_pcm(self, pcm: bytes) -> None:
        """Send 16 kHz PCM to the caller as base64 playAudio messages."""
        # playAudio carries only the event and the media. Vobiz plays these messages
        # on the stream they arrive on.
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
        """Open this call's agent STT session."""
        self.stt = AgentSttAsyncClient(
            api_key=SM_API_KEY,
            url=SM_RT_URL,
            app="speechmatics-academy/vobiz-phone-voice-agent",
            # 16 kHz signed 16-bit PCM is the SDK default and what the Stream element asks Vobiz for.
            # `model` defaults to Linden 1; turns are closed by the service's VAD.
            transcription_config=TranscriptionConfig(language=LANGUAGE, enable_partials=True),
            record_events=False,
        )
        self.register_stt_handlers(self.stt)
        await self.stt.connect()  # returns once the service is ready for audio

    def register_stt_handlers(self, client: AgentSttAsyncClient) -> None:
        """SDK handlers are synchronous callbacks: anything slow is handed to a task."""

        @client.on(ServerMessageType.RECOGNITION_STARTED)
        def on_started(message):
            log("STT       Speechmatics session started", message.get("id"))

        # StartOfTurn fires on the caller's first word; SpeechStarted on voice activity.
        # Either one while the agent is talking means the caller is interrupting.
        @client.on(ServerMessageType.START_OF_TURN)
        @client.on(ServerMessageType.SPEECH_STARTED)
        def on_caller_speaking(_message):
            self.spawn(self.barge_in())

        @client.on(ServerMessageType.ADD_SEGMENT)
        def on_segment(message):
            text = message["segment"]["transcript"].strip()
            if text:
                self.turn_text.append(text)

        # EndOfTurn is the last message of a turn: the moment to answer.
        @client.on(ServerMessageType.END_OF_TURN)
        def on_turn_end(_message):
            text = " ".join(self.turn_text).strip()
            self.turn_text = []
            if text:
                self.turn_ended_at = time.time()
                log(f"CALLER    {text}")
                self.reply_task = self.spawn(self.reply(text))

        @client.on(ServerMessageType.ERROR)
        def on_error(message):
            log("STT       error:", message.get("reason", message))

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
        """Speechmatics TTS: stream 16 kHz PCM straight into playAudio as it arrives."""
        try:
            response = await self.tts.generate(text=text, voice=SM_VOICE, output_format=tts.OutputFormat.RAW_PCM_16000)
        except (tts.AuthenticationError, tts.TransportError) as e:
            log(f"TTS       error: {e}")
            return
        first = True
        carry = b""
        try:
            if response.status != 200:
                log("TTS       error", response.status, (await response.text())[:300])
                return
            self.speaking = True
            async for chunk in response.content.iter_chunked(CHUNK):
                if first and self.turn_ended_at:
                    elapsed_ms = (time.time() - self.turn_ended_at) * 1000
                    log(f"LATENCY   end of caller turn -> first agent audio: {elapsed_ms:.0f} ms")
                    self.turn_ended_at = 0.0
                first = False
                chunk = carry + chunk
                cut = len(chunk) - (len(chunk) % 2)  # send whole 16-bit samples only
                chunk, carry = chunk[:cut], chunk[cut:]
                await self.play_pcm(chunk)
        finally:
            response.release()

    async def reply(self, user_text: str) -> None:
        """Answer one caller turn, speaking each sentence as soon as the LLM writes it."""
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
        """Speak the opening line."""
        log(f"AGENT     {GREETING}")
        self.history.append({"role": "assistant", "content": GREETING})
        await self.speak(GREETING)
        await self.send_vobiz({"event": "checkpoint", "streamId": self.stream_id, "name": "greeting"})

    async def end_after(self, seconds: int) -> None:
        """Stop the stream after the time limit; with no XML after it, Vobiz hangs up."""
        await asyncio.sleep(seconds)
        log(f"CALL      reached the {seconds} s limit, ending the call")
        await self.send_vobiz({"event": "stop", "streamId": self.stream_id})

    # ---------- main loop ----------
    async def run(self) -> None:
        """Handle Vobiz stream events until the call ends."""
        try:
            async for msg in self.vobiz:
                if msg.type != aiohttp.WSMsgType.TEXT:
                    continue
                data = json.loads(msg.data)
                event = data.get("event")
                if event == "media":
                    if self.stt:
                        await self.stt.send_audio(base64.b64decode(data["media"]["payload"]))
                elif event == "start":
                    if self.stt:
                        continue  # one agent STT session per stream
                    start = data["start"]
                    self.stream_id = start.get("streamId")
                    log(f"CALL      started call={start.get('callId')} format={start.get('mediaFormat')}")
                    try:
                        await self.start_stt()
                    except AuthenticationError:
                        log("STT       could not start a Speechmatics session: check SPEECHMATICS_API_KEY")
                        break
                    except Exception as e:  # noqa: BLE001 - network and session errors
                        log(f"STT       could not start a Speechmatics session: {e}")
                        break
                    self.reply_task = self.spawn(self.greet())
                    self.spawn(self.end_after(MAX_CALL_SECONDS))
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
        """Cancel the call's tasks and close its agent STT session."""
        for task in list(self.tasks):
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        if self.stt:
            try:
                # Sends EndOfStream and waits briefly for the service to flush.
                await asyncio.wait_for(self.stt.disconnect(), timeout=5)
            except Exception:  # noqa: BLE001 - the call is over either way
                pass
        log("CALL      ended")


async def answer(_request: web.Request) -> web.Response:
    """Return the VobizXML that connects the call to the audio WebSocket."""
    log("HTTP      answer URL fetched")
    return web.Response(text=answer_xml(), content_type="application/xml")


async def hangup(request: web.Request) -> web.Response:
    """Log the hangup callback Vobiz sends when the call ends."""
    form = await request.post() if request.can_read_body else request.query
    log(f"HTTP      hangup cause={form.get('HangupCause')} duration={form.get('Duration')}")
    return web.Response(text="OK")


async def media_stream(request: web.Request) -> web.WebSocketResponse:
    """Accept the Vobiz audio WebSocket and run one call on it."""
    sock = web.WebSocketResponse()
    await sock.prepare(request)
    if request.app["calls"]["active"] >= MAX_CALLS:
        log(f"CALL      rejected: {MAX_CALLS} calls already in progress")
        await sock.close()
        return sock
    request.app["calls"]["active"] += 1
    try:
        await Call(sock, request.app).run()
    finally:
        request.app["calls"]["active"] -= 1
    return sock


async def on_startup(app: web.Application) -> None:
    """Create the shared HTTP and TTS clients."""
    app["http"] = aiohttp.ClientSession()
    app["tts"] = tts.AsyncClient(api_key=SM_API_KEY)


async def on_cleanup(app: web.Application) -> None:
    """Close the shared HTTP and TTS clients."""
    await app["tts"].close()
    await app["http"].close()


def make_app() -> web.Application:
    """Build the web app with token-protected routes."""
    app = web.Application()
    app["prompt"] = system_prompt()
    app["calls"] = {"active": 0}  # mutable: app state is frozen once the server starts
    app.router.add_route("*", f"/answer/{PATH_TOKEN}", answer)
    app.router.add_route("*", f"/hangup/{PATH_TOKEN}", hangup)
    app.router.add_get(f"/ws/{PATH_TOKEN}", media_stream)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    return app


def check_config() -> None:
    """Exit with a clear message when a required setting is missing."""
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
    log(f"Voice: {SM_VOICE.value}  LLM: {LLM_MODEL}  Listening on http://127.0.0.1:{PORT}")
    web.run_app(make_app(), host="127.0.0.1", port=PORT, print=None)
