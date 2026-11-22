"""
Feature: Startup plumbing - request routing, tunnel URL, env and API errors

    Before any call arrives, the proxy has to:

      - route HTTP requests: serve the answer XML and acknowledge hangup
        callbacks on their per-run token paths, let only the stream path
        through to the WebSocket handler, and 404 everything else;
      - decide its public URL (PUBLIC_URL, or an ngrok tunnel);
      - insist on the env vars it needs;
      - turn every kind of Vobiz API failure into one readable error.

    The random token in the paths is the proxy's only access control, so
    the routing tests matter more than their size suggests.
"""

import io
import urllib.error
from http import HTTPStatus
from unittest.mock import patch

import proxy
import pytest

ANSWER, HANGUP, STREAM = "/answer/tok", "/hangup/tok", "/vobiz/tok"
BODY = b"<Response/>"


@pytest.fixture
def route():
    return proxy.make_process_request(ANSWER, HANGUP, STREAM, BODY)


async def test_answer_path_serves_the_xml(route):
    """
    Scenario: Vobiz fetches the answer URL
        Given the router for this run's token
         When GET /answer/<token>?CallUUID=... arrives
         Then it returns 200 with the XML body and an XML content type

    Purpose:
        Vobiz appends call parameters as a query string on GET; the
        route must still match.
    """
    status, headers, body = await route(f"{ANSWER}?CallUUID=abc&From=%2B91", None)

    assert status == HTTPStatus.OK
    assert ("Content-Type", "application/xml") in headers
    assert body == BODY


async def test_hangup_path_is_acknowledged(route):
    """
    Scenario: Vobiz posts the end of the call
        When GET /hangup/<token>?... arrives
         Then it returns an empty 200
    """
    status, _, body = await route(f"{HANGUP}?Event=Hangup", None)

    assert status == HTTPStatus.OK
    assert body == b""


async def test_stream_path_reaches_the_websocket_handler(route):
    """
    Scenario: Vobiz opens the audio stream
        When the stream path is requested
         Then the router returns None, so the WebSocket handshake proceeds
    """
    assert await route(STREAM, None) is None


@pytest.mark.parametrize(
    "path",
    ["/answer", "/answer/wrong", "/vobiz", "/vobiz/wrong", "/", "/hangup/other"],
)
async def test_other_paths_are_refused(route, path):
    """
    Scenario Outline: A request without this run's token
        When <path> is requested
         Then the router returns 404

    Purpose:
        Anyone who finds the tunnel URL must not be able to read the
        answer XML (it contains the stream URL) or open an audio stream
        that bills the operator's Speechmatics account.
    """
    status, _, _ = await route(path, None)
    assert status == HTTPStatus.NOT_FOUND


async def test_public_url_must_be_https(capsys):
    """
    Scenario: PUBLIC_URL is plain http
        Given PUBLIC_URL=http://example.dev
         When the public URL is resolved
         Then the process exits with code 1 and explains why

    Purpose:
        An http:// base would produce an http:// stream URL, which never
        connects, and the call would carry on with no transcript.
    """
    with (
        patch.object(proxy, "PUBLIC_URL", "http://example.dev"),
        pytest.raises(SystemExit) as exc,
    ):
        await proxy._public_base_url()

    assert exc.value.code == 1
    assert "https://" in capsys.readouterr().err


async def test_public_url_replaces_ngrok():
    """
    Scenario: The operator already runs a tunnel
        Given PUBLIC_URL=https://example.dev/
         When the public URL is resolved
         Then it is used without the trailing slash, and ngrok is not opened
    """
    with (
        patch.object(proxy, "PUBLIC_URL", "https://example.dev/"),
        patch("proxy._start_ngrok_tunnel") as ngrok_start,
    ):
        assert await proxy._public_base_url() == "https://example.dev"
    ngrok_start.assert_not_called()


def test_ngrok_token_is_optional_with_public_url(monkeypatch):
    """
    Scenario: PUBLIC_URL set, NGROK_AUTHTOKEN not
        Given every other required variable is set
         When the env check runs
         Then it passes
          And without PUBLIC_URL the same env fails naming NGROK_AUTHTOKEN
    """
    for name in proxy.ENV_VARS:
        monkeypatch.setenv(name, "x")
    monkeypatch.delenv("NGROK_AUTHTOKEN")

    with patch.object(proxy, "PUBLIC_URL", "https://example.dev"):
        proxy._check_env_vars()

    with patch.object(proxy, "PUBLIC_URL", None), pytest.raises(SystemExit):
        proxy._check_env_vars()


def _http_error(code: int, body: bytes) -> urllib.error.HTTPError:
    return urllib.error.HTTPError("https://api", code, "err", {}, io.BytesIO(body))


@pytest.mark.parametrize(
    "failure, message",
    [
        (_http_error(401, b'{"error":"bad token"}'), "returned 401"),
        (urllib.error.URLError("no route"), "unreachable"),
        (TimeoutError("timed out"), "unreachable"),
    ],
)
def test_vobiz_failures_become_one_error_type(failure, message):
    """
    Scenario Outline: The Vobiz API call fails
        Given urlopen raises <failure>
         When _vobiz_request runs
         Then a VobizAPIError is raised mentioning <message>

    Purpose:
        main() turns VobizAPIError into "Could not configure the Vobiz
        number: ...". Any other exception type would surface as a raw
        traceback after the tunnel is already open.
    """
    with (
        patch("proxy.urllib.request.urlopen", side_effect=failure),
        pytest.raises(proxy.VobizAPIError, match=message),
    ):
        proxy._vobiz_request("GET", "/numbers")


def test_non_json_response_is_a_vobiz_error():
    """
    Scenario: Vobiz answers 200 with an HTML page
        When _vobiz_request decodes the body
         Then a VobizAPIError says the response was not JSON
    """

    class _Response(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

    with (
        patch("proxy.urllib.request.urlopen", return_value=_Response(b"<html>")),
        pytest.raises(proxy.VobizAPIError, match="non-JSON"),
    ):
        proxy._vobiz_request("GET", "/numbers")
