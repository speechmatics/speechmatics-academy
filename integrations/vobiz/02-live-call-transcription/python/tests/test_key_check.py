"""
Feature: Speechmatics key is validated at startup

    A bad SPEECHMATICS_API_KEY would otherwise surface only on the first
    call - after ngrok was up and the Vobiz number had been repointed - so
    everything looked healthy except the one thing that mattered.
    _check_speechmatics_key() runs first in main() and exits before any
    of that is set up.

    JWTAuth is patched, so these tests never touch the network.
"""

from unittest.mock import AsyncMock, patch

import proxy
import pytest

from speechmatics.rt import AuthenticationError


async def test_rejected_key_exits_with_a_clear_message(capsys):
    """
    Scenario: Operator starts the proxy with a bad key
        Given the token request is rejected
         When the startup check runs
         Then the process exits with code 1
          And the message names SPEECHMATICS_API_KEY
          And it says the Vobiz number has not been changed
    """
    auth = AsyncMock()
    auth.get_auth_headers.side_effect = AuthenticationError("HTTP 401: Unauthorized")

    with patch("proxy.JWTAuth", return_value=auth), pytest.raises(SystemExit) as exc:
        await proxy._check_speechmatics_key()

    assert exc.value.code == 1
    err = capsys.readouterr().err
    assert "SPEECHMATICS_API_KEY" in err
    assert "Vobiz number has not been changed" in err


async def test_accepted_key_returns_quietly():
    """
    Scenario: Operator starts the proxy with a valid key
        Given the token request succeeds
         When the startup check runs
         Then it returns without exiting
    """
    auth = AsyncMock()
    auth.get_auth_headers.return_value = {"Authorization": "Bearer jwt"}

    with patch("proxy.JWTAuth", return_value=auth):
        await proxy._check_speechmatics_key()

    auth.get_auth_headers.assert_awaited_once()


async def test_main_checks_the_key_before_starting_ngrok():
    """
    Scenario: Startup order
        Given a key check that exits
         When main() runs
         Then ngrok is never started and the Vobiz number is never touched

    Purpose:
        The whole point is failing before anything has side effects.
    """
    with (
        patch("proxy._check_env_vars"),
        patch("proxy._check_speechmatics_key", side_effect=SystemExit(1)),
        patch("proxy._start_ngrok_tunnel", new_callable=AsyncMock) as ngrok_start,
        patch("proxy._point_vobiz_number") as point_number,
        pytest.raises(SystemExit),
    ):
        await proxy.main([])

    ngrok_start.assert_not_called()
    point_number.assert_not_called()


async def test_network_error_exits_with_the_same_clear_message(capsys):
    """
    Scenario: mp.speechmatics.com cannot be reached
        Given the token request raises a connection error
         When the startup check runs
         Then the process exits with code 1 and the readable message,
              not a traceback
    """
    auth = AsyncMock()
    auth.get_auth_headers.side_effect = OSError("Name or service not known")

    with patch("proxy.JWTAuth", return_value=auth), pytest.raises(SystemExit) as exc:
        await proxy._check_speechmatics_key()

    assert exc.value.code == 1
    assert "mp.speechmatics.com" in capsys.readouterr().err
