"""
Feature: handle_vobiz_call - Vobiz audio stream event loop

    handle_vobiz_call is the WebSocket handler Vobiz talks to for the
    lifetime of one phone call. It:

      - Receives JSON events over the socket ("start", then "media").
      - Creates a CallSession on "start", using the audio format Vobiz
        reports in `start.mediaFormat`.
      - Base64-decodes each "media" payload and routes it to the
        session by track label.
      - Closes the session when the socket closes. Vobiz sends no "stop"
        event, so the end of the stream is the end of the call.

    CallSession is patched to a MagicMock so the real Speechmatics
    client is never contacted - these are pure logic tests for the
    event router.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import proxy
import pytest
import websockets

from speechmatics.rt import AudioEncoding


@pytest.fixture
def mock_session():
    """
    Replace proxy.CallSession with a MagicMock for the duration of a test.

    close() is an AsyncMock because handle_vobiz_call awaits it.
    """
    with patch("proxy.CallSession") as MockSession:
        instance = MagicMock()
        instance.close = AsyncMock()
        MockSession.return_value = instance
        yield MockSession, instance


async def test_start_event_creates_and_starts_session(fake_ws, start_event, mock_session):
    """
    Scenario: A well-formed Vobiz start event
        Given a fake WebSocket queued with [<start>]
         When handle_vobiz_call consumes the stream
         Then CallSession() was constructed once with the L16/16 kHz format
          And session.start() was invoked once

    Purpose:
        Guards the "call kicks off a Speechmatics session" step.
    """
    Session, instance = mock_session

    await proxy.handle_vobiz_call(fake_ws([start_event]))

    Session.assert_called_once_with(proxy.VOBIZ_AUDIO_FORMAT)
    instance.start.assert_called_once()


@pytest.mark.parametrize(
    "encoding, rate, expected_encoding, expected_chunk",
    [
        ("audio/x-l16", 16000, AudioEncoding.PCM_S16LE, 640),
        ("audio/x-l16", 8000, AudioEncoding.PCM_S16LE, 320),
        ("audio/x-mulaw", 8000, AudioEncoding.MULAW, 160),
    ],
)
async def test_session_uses_the_format_vobiz_reports(
    fake_ws,
    start_event,
    mock_session,
    encoding,
    rate,
    expected_encoding,
    expected_chunk,
):
    """
    Scenario Outline: The session decodes audio in the reported format
        Given a start event whose mediaFormat is <encoding>/<rate>
         When handle_vobiz_call consumes it
         Then the session's AudioFormat matches that encoding and rate
          And its chunk_size is one 20 ms frame

    Purpose:
        Vobiz's docs say to decode every payload using start.mediaFormat
        rather than assuming a rate. If someone edits the answer XML's
        contentType, the proxy must follow rather than mis-decode.
    """
    Session, _ = mock_session
    start_event["start"]["mediaFormat"] = {"encoding": encoding, "sampleRate": rate}

    await proxy.handle_vobiz_call(fake_ws([start_event]))

    audio_format = Session.call_args.args[0]
    assert audio_format.encoding == expected_encoding
    assert audio_format.sample_rate == rate
    assert audio_format.chunk_size == expected_chunk


async def test_unsupported_format_skips_transcription(fake_ws, start_event, media_event, mock_session, capsys):
    """
    Scenario: Vobiz reports a format Speechmatics is not given
        Given a start event with mediaFormat audio/x-l16 at 24000 Hz
         When handle_vobiz_call consumes it and a media frame
         Then no CallSession is created
          And the reason is printed on stderr

    Purpose:
        Sending audio under the wrong format produces garbage transcripts
        with no error. Refusing loudly is better.
    """
    Session, instance = mock_session
    start_event["start"]["mediaFormat"] = {
        "encoding": "audio/x-l16",
        "sampleRate": 24000,
    }

    await proxy.handle_vobiz_call(fake_ws([start_event, media_event("inbound")]))

    Session.assert_not_called()
    instance.enqueue.assert_not_called()
    assert "unsupported audio format" in capsys.readouterr().err


async def test_ignores_media_before_start(fake_ws, media_event, mock_session):
    """
    Scenario: A "media" event arrives before "start"
        Given a fake WebSocket queued with [<media>]
         When handle_vobiz_call consumes the stream
         Then session.enqueue was never called

    Purpose:
        Defensive: a reordered or broken stream must not crash the
        handler on a None session.
    """
    _, instance = mock_session

    await proxy.handle_vobiz_call(fake_ws([media_event("inbound")]))

    instance.enqueue.assert_not_called()


async def test_media_event_base64_decoded_and_forwarded(fake_ws, start_event, media_event, mock_session):
    """
    Scenario: A media event with a base64-encoded payload
        Given a stream containing start -> media
          And the media event's payload is base64(bytes(range(32)))
         When handle_vobiz_call consumes the stream
         Then session.enqueue is called once with ("inbound", bytes(range(32)))

    Purpose:
        The exact bytes must be recovered from base64 and land on the
        right track, or the transcript will be garbled.
    """
    _, instance = mock_session
    raw_audio = bytes(range(32))

    await proxy.handle_vobiz_call(fake_ws([start_event, media_event("inbound", raw_audio)]))

    instance.enqueue.assert_called_once_with("inbound", raw_audio)


async def test_both_tracks_forwarded_to_session_by_label(fake_ws, start_event, media_event, mock_session):
    """
    Scenario: Interleaved inbound + outbound media events
        Given a stream containing start -> media(inbound) -> media(outbound)
         When handle_vobiz_call consumes the stream
         Then enqueue was called with ("inbound", <inbound bytes>)
          And enqueue was called with ("outbound", <outbound bytes>)

    Purpose:
        This is the multi-channel diarization contract: the caller
        (inbound) and the callee (outbound) must keep their own labels.
    """
    _, instance = mock_session
    in_bytes = b"\xaa" * 640
    out_bytes = b"\xbb" * 640

    await proxy.handle_vobiz_call(
        fake_ws(
            [
                start_event,
                media_event("inbound", in_bytes),
                media_event("outbound", out_bytes),
            ]
        )
    )

    call_args = [c.args for c in instance.enqueue.call_args_list]
    assert ("inbound", in_bytes) in call_args
    assert ("outbound", out_bytes) in call_args


async def test_media_without_payload_is_skipped(fake_ws, start_event, mock_session):
    """
    Scenario: A media event that is missing the "payload" key
        Given a stream containing start -> {media without payload}
         When handle_vobiz_call consumes the stream
         Then session.enqueue was never called

    Purpose:
        base64.b64decode(None) would raise and kill the whole handler.
    """
    _, instance = mock_session

    await proxy.handle_vobiz_call(fake_ws([start_event, {"event": "media", "media": {"track": "inbound"}}]))

    instance.enqueue.assert_not_called()


async def test_socket_close_ends_the_call(fake_ws, start_event, media_event, mock_session, capsys):
    """
    Scenario: The call ends and Vobiz closes the socket
        Given an active call (start and media received)
         When the stream ends with no "stop" event
         Then session.close() is awaited exactly once
          And "call ended" is printed

    Purpose:
        Vobiz signals the end of a call only by closing the socket. A
        handler that waited for a "stop" event would leak one session
        per call.
    """
    _, instance = mock_session

    await proxy.handle_vobiz_call(fake_ws([start_event, media_event("inbound")]))

    instance.close.assert_awaited_once()
    assert "call ended" in capsys.readouterr().out


async def test_connection_closed_still_closes_session(start_event, mock_session):
    """
    Scenario: The WebSocket drops abruptly mid-call
        Given an active call (start event received)
         When the WebSocket raises ConnectionClosed on the next iteration
         Then session.close() is still awaited exactly once

    Purpose:
        The `finally` block is what makes shutdown safe on an abnormal
        close; this fails loudly if the cleanup moves into the try block.
    """
    _, instance = mock_session

    class DropAfterStart:
        async def __aiter__(self):
            import json as _json

            yield _json.dumps(start_event)
            raise websockets.exceptions.ConnectionClosed(None, None)

    await proxy.handle_vobiz_call(DropAfterStart())

    instance.close.assert_awaited_once()


async def test_no_session_ever_started_is_a_noop(fake_ws, mock_session):
    """
    Scenario: The socket opens and closes with no "start" event
        Given a WebSocket that sends nothing
         When handle_vobiz_call consumes the stream and returns
         Then no exception was raised
          And session.close() was never awaited

    Purpose:
        Guards the `if session:` check inside the finally block.
    """
    _, instance = mock_session

    await proxy.handle_vobiz_call(fake_ws([]))

    instance.close.assert_not_awaited()


async def test_undecodable_payload_drops_the_frame_not_the_call(
    fake_ws, start_event, media_event, mock_session, capsys
):
    """
    Scenario: One media frame has a malformed base64 payload
        Given a call with a good frame, a bad frame, then another good frame
         When handle_vobiz_call consumes the stream
         Then both good frames still reach the session
          And the bad frame is reported on stderr

    Purpose:
        A bad frame should cost one frame of audio, not the call.
    """
    _, instance = mock_session
    bad = {"event": "media", "media": {"track": "inbound", "payload": "abcde"}}

    await proxy.handle_vobiz_call(
        fake_ws(
            [
                start_event,
                media_event("inbound", b"\x01\x02"),
                bad,
                media_event("inbound", b"\x03\x04"),
            ]
        )
    )

    assert [c.args[1] for c in instance.enqueue.call_args_list] == [
        b"\x01\x02",
        b"\x03\x04",
    ]
    instance.close.assert_awaited_once()
    err = capsys.readouterr().err
    assert "dropping undecodable audio frame" in err
    assert "dropped 1 undecodable" in err


async def test_many_bad_frames_log_once_and_are_tallied(fake_ws, start_event, mock_session, capsys):
    """
    Scenario: A stream of malformed frames
        Given five consecutive bad payloads
         When handle_vobiz_call consumes them
         Then the per-frame warning is printed once
          And the end-of-call tally says five were dropped

    Purpose:
        At 50 frames/s per track a per-frame log would bury every other line.
    """
    bad = {"event": "media", "media": {"track": "inbound", "payload": "abcde"}}

    await proxy.handle_vobiz_call(fake_ws([start_event, *([bad] * 5)]))

    err = capsys.readouterr().err
    assert err.count("dropping undecodable audio frame") == 1
    assert "dropped 5 undecodable" in err


async def test_malformed_messages_do_not_end_the_call(start_event, media_event, mock_session, capsys):
    """
    Scenario: A non-JSON message and a media event with no body arrive mid-call
        Given a call with start, a garbage text frame, {"event": "media"},
              then a good media frame
         When handle_vobiz_call consumes the stream
         Then the good frame still reaches the session
          And the non-JSON message is reported on stderr

    Purpose:
        One malformed message used to raise out of the loop, leaving the
        rest of the call untranscribed.
    """
    import json as _json

    _, instance = mock_session

    class _WS:
        def __aiter__(self):
            return self._gen()

        async def _gen(self):
            yield _json.dumps(start_event)
            yield "not json"
            yield _json.dumps({"event": "media"})
            yield _json.dumps(media_event("inbound", b"\x05\x06"))

    await proxy.handle_vobiz_call(_WS())

    instance.enqueue.assert_called_once_with("inbound", b"\x05\x06")
    assert "non-JSON" in capsys.readouterr().err


async def test_payload_with_stray_characters_is_rejected(fake_ws, start_event, mock_session, capsys):
    """
    Scenario: A payload contains characters outside the base64 alphabet
        Given a media payload "AAAA!!AA"
         When handle_vobiz_call decodes it
         Then the frame is dropped and counted, not forwarded

    Purpose:
        Lenient decoding silently skips stray characters and forwards
        garbled audio.
    """
    _, instance = mock_session
    bad = {"event": "media", "media": {"track": "inbound", "payload": "AAAA!!AA"}}

    await proxy.handle_vobiz_call(fake_ws([start_event, bad]))

    instance.enqueue.assert_not_called()
    assert "dropped 1 undecodable" in capsys.readouterr().err
