#!/usr/bin/env python3
"""
Vobiz Voice <-> Speechmatics Realtime proxy server (multi-channel).

Bridges a Vobiz audio stream to Speechmatics' Realtime API using channel
diarization. The answer XML forks the call with `audioTrack="both"`, so
each call produces two per-speaker transcript streams (inbound / outbound),
transcribed via a single Speechmatics RT multi-channel session.

Run:
    python proxy.py

The server listens on localhost:<PORT>. On startup it uses PUBLIC_URL, or
opens an ngrok tunnel when that is unset, and points the configured Vobiz
number at the tunnel's /answer endpoint through a Vobiz application. Dial
the Vobiz number to start a call. With --call it places an outbound call
instead, and with --no-setup it only prints the answer URL; neither changes
the number's routing.
"""

import argparse
import asyncio
import base64
import binascii
import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
from html import escape
from http import HTTPStatus

import ngrok
import ui
import websockets
from dotenv import load_dotenv

from speechmatics.rt import (
    AsyncMultiChannelClient,
    AudioEncoding,
    AudioFormat,
    AuthenticationError,
    JWTAuth,
    Model,
    ServerMessageType,
    TranscriptionConfig,
    TranscriptResult,
)

load_dotenv()

SM_API_KEY = os.getenv("SPEECHMATICS_API_KEY")
NGROK_AUTHTOKEN = os.getenv("NGROK_AUTHTOKEN")
VOBIZ_AUTH_ID = os.getenv("VOBIZ_AUTH_ID")
VOBIZ_AUTH_TOKEN = os.getenv("VOBIZ_AUTH_TOKEN")
VOBIZ_PHONE_NUMBER = os.getenv("VOBIZ_PHONE_NUMBER")
FORWARD_TO_NUMBER = os.getenv("FORWARD_TO_NUMBER")
PUBLIC_URL = os.getenv("PUBLIC_URL")
PORT = int(os.getenv("SM_VOBIZ_PROXY_PORT", "5000"))
LANGUAGE = os.getenv("SPEECHMATICS_LANGUAGE") or "en"
CHANNELS = ["inbound", "outbound"]
# Upper bound on a bridged call, in seconds. Each call bills telephony and a
# Speechmatics session for as long as it lasts.
MAX_CALL_SECONDS = int(os.getenv("MAX_CALL_SECONDS", "3600"))

VOBIZ_API_BASE = "https://api.vobiz.ai/api/v1"
VOBIZ_APP_PREFIX = "speechmatics-transcription"

ENV_VARS = (
    "SPEECHMATICS_API_KEY",
    "NGROK_AUTHTOKEN",
    "VOBIZ_AUTH_ID",
    "VOBIZ_AUTH_TOKEN",
    "VOBIZ_PHONE_NUMBER",
    "FORWARD_TO_NUMBER",
)

# The answer XML asks Vobiz for 16-bit linear PCM at 16 kHz, in 20 ms frames
# (640 bytes each), base64-encoded inside JSON. Speechmatics Realtime accepts
# this natively, so frames are forwarded without transcoding.
VOBIZ_CONTENT_TYPE = "audio/x-l16;rate=16000"
VOBIZ_AUDIO_FORMAT = AudioFormat(
    encoding=AudioEncoding.PCM_S16LE,
    sample_rate=16000,
    chunk_size=640,
)

# Vobiz reports the format it actually sends in `start.mediaFormat`.
SUPPORTED_MEDIA_FORMATS = {
    ("audio/x-l16", 16000): VOBIZ_AUDIO_FORMAT,
    ("audio/x-l16", 8000): AudioFormat(encoding=AudioEncoding.PCM_S16LE, sample_rate=8000, chunk_size=320),
    ("audio/x-mulaw", 8000): AudioFormat(encoding=AudioEncoding.MULAW, sample_rate=8000, chunk_size=160),
}


class AsyncQueueSource:
    """File-like async source backed by an asyncio.Queue of audio frames.

    read() blocks until data is available, returning empty bytes only on
    explicit close() - otherwise the multi-channel SDK would treat a
    stall as EOF and tear down the whole session.
    """

    def __init__(self) -> None:
        self._queue: asyncio.Queue[bytes] = asyncio.Queue()
        self._buffer = b""
        self._closed = False

    # About 10 s of 20 ms frames. A backlog beyond that means audio is arriving faster
    # than real time; drop it rather than let memory grow without limit.
    MAX_QUEUED_FRAMES = 500

    def enqueue(self, data: bytes) -> None:
        """Queue one audio frame unless the source is closed or the backlog is full."""
        if data and not self._closed and self._queue.qsize() < self.MAX_QUEUED_FRAMES:
            self._queue.put_nowait(data)

    def close(self) -> None:
        """Signal end of audio to the reader."""
        # Signal EOF; the sentinel unblocks any pending read().
        self._closed = True
        self._queue.put_nowait(b"")

    async def read(self, n: int) -> bytes:
        """Return up to n bytes, waiting for audio; empty bytes only after close()."""
        while len(self._buffer) < n:
            chunk = await self._queue.get()
            if not chunk:
                # EOF sentinel. Put it back so subsequent reads also see EOF,
                # then return whatever we have (may be a short read or empty).
                self._queue.put_nowait(b"")
                break
            self._buffer += chunk

        out, self._buffer = self._buffer[:n], self._buffer[n:]
        return out


class CallSession:
    """One Speechmatics multi-channel session covering both Vobiz tracks."""

    def __init__(self, audio_format: AudioFormat = VOBIZ_AUDIO_FORMAT) -> None:
        self.audio_format = audio_format
        self.sources: dict[str, AsyncQueueSource] = {channel: AsyncQueueSource() for channel in CHANNELS}
        self._closed = False
        self._task: asyncio.Task | None = None
        # Track the last speaker so consecutive finals from the same channel
        # continue on one line and speaker-changes start a new line.
        self._last_final_channel: str | None = None

    def start(self) -> None:
        """Start the Speechmatics session in the background."""
        self._task = asyncio.create_task(self._run())

    def enqueue(self, track: str, frame: bytes) -> None:
        """Route one frame to its channel's source by Vobiz track label."""
        if self._closed or track not in self.sources:
            return
        self.sources[track].enqueue(frame)

    async def close(self) -> None:
        """Close both sources and wait for the final transcripts."""
        self._closed = True
        for source in self.sources.values():
            source.close()
        if self._task:
            await self._task

    def _print_final(self, channel: str, text: str) -> None:
        """Print one final transcript chunk under its channel label."""
        if self._last_final_channel is None:
            sys.stdout.write(f"[{channel:<8}] {text}")
        elif channel != self._last_final_channel:
            sys.stdout.write(f"\n[{channel:<8}] {text}")
        else:
            sys.stdout.write(text)
        self._last_final_channel = channel
        sys.stdout.flush()
        ui.publish({"type": "final", "channel": channel, "text": text})

    async def _run(self) -> None:
        transcription_config = TranscriptionConfig(
            language=LANGUAGE,
            max_delay=0.7,
            enable_partials=True,
            model=Model.ENHANCED,
            diarization="channel",
            channel_diarization_labels=CHANNELS,
        )

        try:
            async with AsyncMultiChannelClient(api_key=SM_API_KEY) as client:
                # transcribe() returns as soon as the sources hit EOF.
                # The server still needs a moment to flush its final transcripts.
                eot = asyncio.Event()

                @client.on(ServerMessageType.END_OF_TRANSCRIPT)
                def _on_eot(_msg):
                    eot.set()

                @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
                def _on_partial(msg):
                    # Partials only go to the web UI, not the console.
                    text = TranscriptResult.from_message(msg).metadata.transcript
                    ui.publish({"type": "partial", "channel": msg.get("channel", "?"), "text": text})

                @client.on(ServerMessageType.ADD_TRANSCRIPT)
                def _on_final(msg):
                    text = TranscriptResult.from_message(msg).metadata.transcript
                    channel = msg.get("channel", "?")
                    if not text:
                        return
                    self._print_final(channel, text)

                await client.transcribe(
                    sources=self.sources,
                    transcription_config=transcription_config,
                    audio_format=self.audio_format,
                )
                try:
                    await asyncio.wait_for(eot.wait(), timeout=10.0)
                # asyncio.TimeoutError, not the builtin: they differ on 3.10.
                except asyncio.TimeoutError:  # noqa: UP041
                    print("Timed out waiting for END_OF_TRANSCRIPT", file=sys.stderr)
                sys.stdout.write("\n")
                sys.stdout.flush()
        except AuthenticationError as e:
            print(f"Speechmatics auth error: {e}", file=sys.stderr)
        except Exception as e:  # noqa: BLE001
            if not self._closed:
                print(
                    f"Speechmatics session error: {type(e).__name__}: {e}",
                    file=sys.stderr,
                )
        finally:
            # Stop accepting further audio from Vobiz; the RT connection
            # already closed on the way out of the `async with` above.
            self._closed = True
            for source in self.sources.values():
                source.close()


def _audio_format_for(media_format: dict) -> AudioFormat | None:
    """Map Vobiz's `start.mediaFormat` to a Speechmatics AudioFormat."""
    key = (media_format.get("encoding"), media_format.get("sampleRate"))
    return SUPPORTED_MEDIA_FORMATS.get(key)


async def handle_vobiz_call(ws) -> None:
    """Consume a Vobiz audio stream WebSocket and pump audio into a session."""
    session: CallSession | None = None
    stream_id: str | None = None
    bad_frames = 0

    try:
        async for raw in ws:
            try:
                message = json.loads(raw)
            except ValueError:
                print("[vobiz] skipping a non-JSON message", file=sys.stderr)
                continue
            if not isinstance(message, dict):
                continue
            event = message.get("event")

            if event == "start":
                if session is not None:
                    continue  # one Speechmatics session per stream
                start = message.get("start") or {}
                stream_id = start.get("streamId")
                media_format = start.get("mediaFormat", {})
                print(
                    f"[vobiz] call started - stream={stream_id} "
                    f"call={start.get('callId')} tracks={start.get('tracks')} "
                    f"format={media_format.get('encoding')}/{media_format.get('sampleRate')}"
                )
                ui.publish(
                    {
                        "type": "call_started",
                        "callId": start.get("callId"),
                        "format": f"{media_format.get('encoding')}/{media_format.get('sampleRate')}",
                    }
                )
                audio_format = _audio_format_for(media_format)
                if audio_format is None:
                    print(
                        f"[vobiz] unsupported audio format {media_format}; this call will not be transcribed",
                        file=sys.stderr,
                    )
                    continue
                session = CallSession(audio_format)
                session.start()

            elif event == "media" and session is not None:
                media = message.get("media") or {}
                # Vobiz labels each frame "inbound" (caller) or "outbound" (callee).
                payload = media.get("payload")
                if payload:
                    try:
                        # validate=True: reject stray characters instead of
                        # silently dropping them and forwarding garbled audio.
                        frame = base64.b64decode(payload, validate=True)
                    except (binascii.Error, ValueError, TypeError) as e:
                        bad_frames += 1
                        if bad_frames == 1:
                            print(
                                f"[vobiz] dropping undecodable audio frame ({e}); "
                                "further bad frames are counted, not logged",
                                file=sys.stderr,
                            )
                        continue
                    session.enqueue(media.get("track", "inbound"), frame)

    # Vobiz sends no "stop" event: the socket closing is the end of the call.
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        if bad_frames:
            print(
                f"[vobiz] dropped {bad_frames} undecodable audio frame(s) (stream={stream_id})",
                file=sys.stderr,
            )
        if session:
            await session.close()
        print(f"[vobiz] call ended (stream={stream_id})")
        ui.publish({"type": "call_ended"})


def _check_env_vars() -> None:
    """Exit if a required setting is missing from .env."""
    missing = [name for name in ENV_VARS if not os.getenv(name)]
    if PUBLIC_URL and "NGROK_AUTHTOKEN" in missing:
        missing.remove("NGROK_AUTHTOKEN")  # an existing tunnel replaces ngrok
    if missing:
        print(f"Missing required env vars in .env: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)


async def _check_speechmatics_key() -> None:
    """
    Prove the Speechmatics key works before anything else is set up.

    Without this, a bad key only surfaces on the first call - after ngrok is
    up and the Vobiz number has been repointed - so everything looks healthy
    except the one thing that matters. Minting a short-lived token is the
    cheapest request that rejects an invalid key. The token is discarded.
    """
    try:
        await JWTAuth(SM_API_KEY, ttl=60).get_auth_headers()
    except Exception as e:  # noqa: BLE001 - auth failures and network errors alike
        print(
            f"Could not authenticate with Speechmatics: {e}\n"
            "Check SPEECHMATICS_API_KEY in .env (and that mp.speechmatics.com is "
            "reachable). Nothing has been started and your Vobiz number has not "
            "been changed.",
            file=sys.stderr,
        )
        sys.exit(1)


async def _start_ngrok_tunnel() -> str:
    """Returns the tunnel base URL (https://...)."""
    listener = await ngrok.forward(addr=PORT, authtoken=NGROK_AUTHTOKEN, proto="http")
    return listener.url()


def _build_answer_xml(stream_url: str, forward_to: str, caller_id: str) -> bytes:
    """Build the VobizXML that Vobiz fetches when a call comes in.

    A one-way <Stream> does not block, so Vobiz moves straight on to <Speak>
    and <Dial> while it keeps forking both sides of the call to the proxy.
    """
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        "<Response>"
        f'<Stream audioTrack="both" contentType="{VOBIZ_CONTENT_TYPE}">'
        f"{escape(stream_url)}</Stream>"
        "<Speak>This call is being transcribed.</Speak>"
        f'<Dial callerId="{escape(caller_id)}" timeout="30" timeLimit="{MAX_CALL_SECONDS}"><Number>{escape(forward_to)}</Number></Dial>'
        "</Response>"
    ).encode()


class VobizAPIError(RuntimeError):
    """Any failed Vobiz REST call: error status, network error or bad body."""


def _vobiz_request(method: str, path: str, body: dict | None = None) -> dict:
    """Call the Vobiz REST API and return the decoded JSON response."""
    request = urllib.request.Request(
        f"{VOBIZ_API_BASE}/Account/{VOBIZ_AUTH_ID}{path}",
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "X-Auth-ID": VOBIZ_AUTH_ID or "",
            "X-Auth-Token": VOBIZ_AUTH_TOKEN or "",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        raise VobizAPIError(f"Vobiz API {method} {path} returned {e.code}: {detail}") from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise VobizAPIError(f"Vobiz API {method} {path} unreachable: {e}") from e
    except ValueError as e:  # includes json.JSONDecodeError
        raise VobizAPIError(f"Vobiz API {method} {path} returned non-JSON") from e


def _app_name() -> str:
    """One application per number, so two people on an account don't collide."""
    digits = "".join(c for c in VOBIZ_PHONE_NUMBER or "" if c.isdigit())
    return f"{VOBIZ_APP_PREFIX}-{digits}"


def _find_app(name: str) -> dict | None:
    """Page through the account's applications looking for `name`."""
    offset = 0
    while True:
        page = _vobiz_request("GET", f"/Application/?limit=100&offset={offset}")
        objects = page.get("objects") or []
        app = next((a for a in objects if a.get("app_name") == name), None)
        meta = page.get("meta") or {}
        offset += len(objects)
        if app or not objects or not meta.get("next"):
            return app
        if meta.get("total_count") is not None and offset >= meta["total_count"]:
            return None


def _point_vobiz_number(answer_url: str, hangup_url: str) -> str | None:
    """Route the Vobiz number to our /answer endpoint.

    Creates (or updates) a Vobiz application named after the number and
    attaches the number to it. Returns the app_id the number was attached
    to before, so the operator can switch it back.
    """
    encoded = urllib.parse.quote(VOBIZ_PHONE_NUMBER or "", safe="")
    numbers = _vobiz_request("GET", f"/numbers?search={encoded}").get("items") or []
    number = next((n for n in numbers if n.get("e164") == VOBIZ_PHONE_NUMBER), None)
    if number is None:
        print(
            f"Vobiz number {VOBIZ_PHONE_NUMBER} not found on this account.",
            file=sys.stderr,
        )
        sys.exit(1)
    previous_app = number.get("application_id") or None

    app_fields = {
        "answer_url": answer_url,
        "answer_method": "GET",
        "hangup_url": hangup_url,
        "hangup_method": "GET",
    }
    name = _app_name()
    app = _find_app(name)
    if app is None:
        created = _vobiz_request("POST", "/Application/", {"app_name": name, **app_fields})
        app_id = created.get("app_id")
        if not app_id:
            raise VobizAPIError(f"Vobiz did not return an app_id for {name}: {created}")
    else:
        app_id = app["app_id"]
        _vobiz_request("POST", f"/Application/{app_id}/", app_fields)

    _vobiz_request("POST", f"/numbers/{encoded}/application", {"application_id": app_id})
    return previous_app if previous_app != app_id else None


def _place_outbound_call(to: str, answer_url: str, hangup_url: str) -> str:
    """Have Vobiz call `to` from the Vobiz number; returns the request UUID.

    When `to` answers, Vobiz fetches the same answer XML as an inbound call,
    so the call is forked to the proxy and bridged to FORWARD_TO_NUMBER.
    """
    response = _vobiz_request(
        "POST",
        "/Call/",
        {
            "from": VOBIZ_PHONE_NUMBER,
            "to": to,
            "answer_url": answer_url,
            "answer_method": "GET",
            "hangup_url": hangup_url,
            "hangup_method": "GET",
            "time_limit": MAX_CALL_SECONDS,
        },
    )
    return response.get("request_uuid", "")


def _parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the --call and --no-setup options."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[1])
    parser.add_argument(
        "--no-setup",
        action="store_true",
        help="only serve the answer URL and UI: do not repoint the number or "
        "place a call (point a call at the printed answer URL yourself)",
    )
    parser.add_argument(
        "--call",
        metavar="NUMBER",
        help="place an outbound call to this E.164 number instead of waiting "
        "for an inbound call; it is bridged to FORWARD_TO_NUMBER on answer",
    )
    return parser.parse_args(argv)


async def _public_base_url() -> str:
    """Use PUBLIC_URL if you already run a tunnel, otherwise open ngrok."""
    if PUBLIC_URL:
        if not PUBLIC_URL.startswith("https://"):
            print(
                f"PUBLIC_URL must start with https:// (got {PUBLIC_URL}). Vobiz "
                "fetches /answer over HTTPS and opens the audio stream over wss://.",
                file=sys.stderr,
            )
            sys.exit(1)
        return PUBLIC_URL.rstrip("/")
    return await _start_ngrok_tunnel()


def make_process_request(
    answer_path: str,
    hangup_path: str,
    stream_path: str,
    answer_body: bytes,
    ui_path: str | None = None,
    ui_body: bytes = b"",
    events_path: str | None = None,
):
    """Build the HTTP router that runs before each WebSocket handshake.

    Serves the answer XML and acknowledges hangup callbacks; lets only the
    stream path through to the WebSocket handler, and 404s everything else.
    """

    async def process_request(path, _headers):
        route = path.split("?", 1)[0]
        if route == answer_path:
            return (
                HTTPStatus.OK,
                [
                    ("Content-Type", "application/xml"),
                    ("Content-Length", str(len(answer_body))),
                ],
                answer_body,
            )
        if route == hangup_path:
            return HTTPStatus.OK, [("Content-Length", "0")], b""
        if ui_path and route == ui_path:
            return (
                HTTPStatus.OK,
                [("Content-Type", "text/html; charset=utf-8"), ("Content-Length", str(len(ui_body)))],
                ui_body,
            )
        if events_path and route == events_path:
            return None
        if route != stream_path:
            return HTTPStatus.NOT_FOUND, [("Content-Length", "0")], b""
        return None

    return process_request


async def ws_handler(websocket, _path=None):
    """Route a WebSocket to the transcript page events or the Vobiz audio handler."""
    path = (_path or getattr(websocket, "path", "") or "").split("?", 1)[0]
    if path.startswith("/events/"):
        await ui.serve_events(websocket)
        return
    print("[vobiz] incoming audio stream connection")
    await handle_vobiz_call(websocket)


async def main(argv: list[str] | None = None) -> None:
    """Check settings, configure Vobiz, and serve until interrupted."""
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    _check_env_vars()
    await _check_speechmatics_key()

    # A random path segment keeps the answer XML and audio socket private to
    # this run. The audio stream WebSocket is unsigned, and Vobiz only signs
    # HTTP callbacks when callback credentials are configured.
    token = secrets.token_urlsafe(16)
    answer_path, hangup_path, stream_path = (
        f"/answer/{token}",
        f"/hangup/{token}",
        f"/vobiz/{token}",
    )

    base_url = await _public_base_url()
    wss_url = base_url.replace("https://", "wss://") + stream_path
    answer_body = _build_answer_xml(wss_url, FORWARD_TO_NUMBER, VOBIZ_PHONE_NUMBER)
    ui_path, events_path = f"/ui/{token}", f"/events/{token}"
    ui_body = ui.page(events_path, VOBIZ_PHONE_NUMBER, FORWARD_TO_NUMBER, LANGUAGE)
    previous_app = None
    if not args.call and not args.no_setup:
        try:
            previous_app = await asyncio.to_thread(_point_vobiz_number, base_url + answer_path, base_url + hangup_path)
        except RuntimeError as e:
            print(f"Could not configure the Vobiz number: {e}", file=sys.stderr)
            sys.exit(1)

    process_request = make_process_request(
        answer_path,
        hangup_path,
        stream_path,
        answer_body,
        ui_path=ui_path,
        ui_body=ui_body,
        events_path=events_path,
    )
    async with websockets.serve(ws_handler, "localhost", PORT, process_request=process_request):
        print(f"\nListening on ws://localhost:{PORT}/vobiz/<token>")
        print(f"Live transcript UI: http://localhost:{PORT}{ui_path}")
        if args.no_setup:
            print(f"Answer URL (point a Vobiz call or application here): {base_url}{answer_path}")
            print(f"Hangup URL: {base_url}{hangup_path}")
        elif args.call:
            try:
                request_uuid = await asyncio.to_thread(
                    _place_outbound_call,
                    args.call,
                    base_url + answer_path,
                    base_url + hangup_path,
                )
            except RuntimeError as e:
                print(f"Could not place the call: {e}", file=sys.stderr)
                sys.exit(1)
            print(
                f"Calling {args.call} from {VOBIZ_PHONE_NUMBER} (request={request_uuid}). "
                f"When they answer, they are bridged to {FORWARD_TO_NUMBER}."
            )
        else:
            print(
                f"Vobiz number {VOBIZ_PHONE_NUMBER} pointed at {base_url}/answer/<token> "
                f"(application {_app_name()}). Call it now."
            )
        if previous_app:
            print(f"(It was attached to Vobiz application {previous_app}; re-attach it there when you are done.)")
        print()
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutting down.")
