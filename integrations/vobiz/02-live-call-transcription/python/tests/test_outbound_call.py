"""
Feature: Outbound mode (python proxy.py --call NUMBER)

    Instead of waiting for someone to dial in, the proxy can have Vobiz
    place the call. When the called person answers, Vobiz fetches the same
    answer XML as an inbound call, so the call is forked to the proxy and
    bridged to FORWARD_TO_NUMBER.

    Outbound mode does not touch the number's inbound routing: the answer
    URL travels with the call request instead of an application.

    The Vobiz API, ngrok and the WebSocket server are patched, so these
    tests never touch the network.
"""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import proxy

ANSWER = "https://tunnel.example.dev/answer/abc"
HANGUP = "https://tunnel.example.dev/hangup/abc"


def test_call_request_uses_the_vobiz_number_and_get_callbacks():
    """
    Scenario: Placing the call
        Given a destination number
         When the outbound call is placed
         Then Vobiz is asked to call it from VOBIZ_PHONE_NUMBER
          And the answer and hangup URLs use GET
          And the request UUID from the response is returned

    Purpose:
        The proxy's server only answers GET, and Vobiz rejects a `from`
        number the account does not own.
    """
    with (
        patch.object(proxy, "VOBIZ_PHONE_NUMBER", "+917700900456"),
        patch("proxy._vobiz_request", return_value={"request_uuid": "req-1"}) as request,
    ):
        assert proxy._place_outbound_call("+917700900123", ANSWER, HANGUP) == "req-1"

    request.assert_called_once_with(
        "POST",
        "/Call/",
        {
            "from": "+917700900456",
            "to": "+917700900123",
            "answer_url": ANSWER,
            "answer_method": "GET",
            "hangup_url": HANGUP,
            "hangup_method": "GET",
        },
    )


def test_call_flag_is_parsed():
    """
    Scenario: Command-line flags
        Given `--call +917700900123`
         When the arguments are parsed
         Then args.call is that number
          And with no flags args.call is None (inbound mode)
    """
    assert proxy._parse_args(["--call", "+917700900123"]).call == "+917700900123"
    assert proxy._parse_args([]).call is None


async def _run_main_until_listening(argv):
    """Run main() with every side effect patched; stop once it is serving."""
    serving = asyncio.Event()
    events = []

    class _Server:
        async def __aenter__(self):
            events.append("listening")
            serving.set()

        async def __aexit__(self, *exc):
            return False

    with (
        patch.object(proxy, "VOBIZ_PHONE_NUMBER", "+917700900456"),
        patch.object(proxy, "FORWARD_TO_NUMBER", "+917700900789"),
        patch("proxy._check_env_vars"),
        patch("proxy._check_speechmatics_key", new_callable=AsyncMock),
        patch(
            "proxy._public_base_url",
            new_callable=AsyncMock,
            return_value="https://tunnel.example.dev",
        ),
        patch("proxy._point_vobiz_number", return_value=None) as point_number,
        patch(
            "proxy._place_outbound_call",
            side_effect=lambda *a: events.append("call placed") or "req-1",
        ) as place_call,
        patch("proxy.websockets.serve", return_value=_Server()),
        patch("proxy.asyncio.Future", MagicMock(side_effect=lambda: serving.wait())),
    ):
        await proxy.main(argv)
    return point_number, place_call, events


async def test_outbound_mode_places_the_call_and_leaves_routing_alone():
    """
    Scenario: Running with --call
        Given `--call +917700900123`
         When main() starts
         Then the call is placed once the server is listening
          And the number's inbound routing is not changed
    """
    point_number, place_call, events = await _run_main_until_listening(["--call", "+917700900123"])

    assert events == ["listening", "call placed"]
    point_number.assert_not_called()
    place_call.assert_called_once()
    assert place_call.call_args.args[0] == "+917700900123"
    assert place_call.call_args.args[1].startswith("https://tunnel.example.dev/answer/")


async def test_inbound_mode_points_the_number_and_places_no_call():
    """
    Scenario: Running with no flags
        Given no arguments
         When main() starts
         Then the number is pointed at the proxy
          And no outbound call is placed
    """
    point_number, place_call, _ = await _run_main_until_listening([])

    point_number.assert_called_once()
    place_call.assert_not_called()
