"""
Shared pytest fixtures and helpers for the proxy test suite.

The tests here never contact Vobiz, ngrok, or Speechmatics. Instead:

  - `fake_ws` builds an async-iterable object that yields JSON-encoded
    Vobiz audio stream events, exactly the way the real `websockets`
    server would deliver them to `handle_vobiz_call`. Iteration simply
    ends after the last event, which is how a real Vobiz stream ends:
    the socket closes, with no "stop" event.

  - `media_event` / `start_event` produce well-formed Vobiz event
    dicts so tests don't repeat boilerplate.

Keep all shared test data here so individual test files stay focused
on the behaviour they're proving.
"""

import base64
import json
from collections.abc import Iterable

import pytest


@pytest.fixture
def fake_ws():
    """
    Factory fixture: build an async-iterable WebSocket stand-in.

    Usage:
        ws = fake_ws([start_event, media_event("inbound")])
        await handle_vobiz_call(ws)

    Each dict is JSON-encoded and yielded in order, mimicking exactly
    how `websockets` delivers text frames from a live client.
    """

    class _FakeWS:
        def __init__(self, messages: Iterable[dict]) -> None:
            self._messages = [json.dumps(m) for m in messages]

        def __aiter__(self):
            return self._async_iter()

        async def _async_iter(self):
            for msg in self._messages:
                yield msg

    return _FakeWS


@pytest.fixture
def media_event():
    """
    Factory fixture: build a well-formed Vobiz 'media' event dict.

    Usage:
        event = media_event("inbound", b"\\x01\\x02\\x03")

    The `payload` field is base64-encoded exactly like Vobiz does on
    the wire, so the handler under test exercises the real decode path.
    """

    def _build(track: str = "inbound", payload_bytes: bytes = b"\x01\x02\x03"):
        return {
            "sequenceNumber": 2,
            "streamId": "c4dfd815-a92a-4140-ab85-5ff28c004116",
            "event": "media",
            "media": {
                "track": track,
                "timestamp": "1778597597091",
                "chunk": 2,
                "payload": base64.b64encode(payload_bytes).decode(),
            },
            "extra_headers": "{}",
        }

    return _build


@pytest.fixture
def start_event():
    """
    Canned Vobiz 'start' event dict for a both-track L16/16 kHz stream.

    The identifiers live inside the nested `start` object, as they do on
    the wire. They are only logged, so any well-formed values work.
    """
    return {
        "sequenceNumber": 0,
        "event": "start",
        "start": {
            "callId": "5401fd2e-6344-40df-a22c-c8ffea7a92e7",
            "streamId": "c4dfd815-a92a-4140-ab85-5ff28c004116",
            "accountId": "500025",
            "tracks": ["inbound", "outbound"],
            "mediaFormat": {"encoding": "audio/x-l16", "sampleRate": 16000},
        },
        "extra_headers": "{}",
    }
