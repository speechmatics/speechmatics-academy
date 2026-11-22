"""
Feature: Pointing the Vobiz number at the proxy (_point_vobiz_number)

    Vobiz routes an inbound call through the application its number is
    attached to. On startup the proxy:

      1. Looks the number up on the account (GET /numbers?search=...).
      2. Creates an application named after the number
         (speechmatics-transcription-<digits>), or updates the existing
         one, with GET answer and hangup URLs on the tunnel.
      3. Attaches the number to that application.

    _vobiz_request is patched, so these tests never touch the network.
"""

from unittest.mock import patch

import proxy
import pytest

NUMBER = "+917700900123"
ANSWER = "https://tunnel.example.dev/answer/abc"
HANGUP = "https://tunnel.example.dev/hangup/abc"
APP_NAME = "speechmatics-transcription-917700900123"


def _fake_api(number_app=None, existing_apps=()):
    """Build a stand-in for _vobiz_request plus the list of calls it saw."""
    calls = []

    def _request(method, path, body=None):
        calls.append((method, path, body))
        if method == "GET" and path.startswith("/numbers"):
            return {"items": [{"e164": NUMBER, "application_id": number_app}]}
        if method == "GET" and path.startswith("/Application/"):
            return {"objects": list(existing_apps), "meta": {"next": None}}
        if method == "POST" and path == "/Application/":
            return {"app_id": "111", "message": "created"}
        return {"message": "ok"}

    return _request, calls


@pytest.fixture(autouse=True)
def vobiz_number():
    with patch.object(proxy, "VOBIZ_PHONE_NUMBER", NUMBER):
        yield


def test_creates_the_app_and_attaches_the_number():
    """
    Scenario: First run on an account
        Given no application named after the number exists
         When the number is pointed at the proxy
         Then an application is created with GET answer and hangup URLs
          And the number is attached to it, URL-encoded in the path

    Purpose:
        The proxy's server only answers GET, and Vobiz needs the "+" in
        the number path encoded as %2B or the number is not matched.
    """
    request, calls = _fake_api()
    with patch("proxy._vobiz_request", side_effect=request):
        proxy._point_vobiz_number(ANSWER, HANGUP)

    created = next(c for c in calls if c[:2] == ("POST", "/Application/"))
    assert created[2] == {
        "app_name": APP_NAME,
        "answer_url": ANSWER,
        "answer_method": "GET",
        "hangup_url": HANGUP,
        "hangup_method": "GET",
    }
    assert (
        "POST",
        "/numbers/%2B917700900123/application",
        {"application_id": "111"},
    ) in calls


def test_reuses_the_existing_app():
    """
    Scenario: A later run on the same account
        Given an application named after the number already exists
         When the number is pointed at the proxy
         Then that application's URLs are updated in place
          And no second application is created

    Purpose:
        Each run gets a new tunnel URL. Creating an application per run
        would litter the account.
    """
    existing = {"app_id": "222", "app_name": APP_NAME}
    request, calls = _fake_api(existing_apps=[existing])
    with patch("proxy._vobiz_request", side_effect=request):
        proxy._point_vobiz_number(ANSWER, HANGUP)

    assert not any(c[:2] == ("POST", "/Application/") for c in calls)
    update = next(c for c in calls if c[:2] == ("POST", "/Application/222/"))
    assert update[2]["answer_url"] == ANSWER
    assert (
        "POST",
        "/numbers/%2B917700900123/application",
        {"application_id": "222"},
    ) in calls


def test_returns_the_previous_app_so_it_can_be_restored():
    """
    Scenario: The number was routed somewhere else before
        Given the number is attached to application 999
         When the number is pointed at the proxy
         Then 999 is returned

    Purpose:
        Attaching overwrites the old binding. Telling the operator what
        it was lets them put production routing back.
    """
    request, _ = _fake_api(number_app="999")
    with patch("proxy._vobiz_request", side_effect=request):
        assert proxy._point_vobiz_number(ANSWER, HANGUP) == "999"


def test_unknown_number_exits_without_changes(capsys):
    """
    Scenario: The number does not belong to this account
        Given the number search returns no exact match
         When the number is pointed at the proxy
         Then the process exits with code 1
          And no application is created or attached

    Purpose:
        A typo in VOBIZ_PHONE_NUMBER should fail clearly, not create an
        application that nothing routes to.
    """
    calls = []

    def request(method, path, body=None):
        calls.append((method, path))
        return {"items": [{"e164": "+910000000000"}]}

    with (
        patch("proxy._vobiz_request", side_effect=request),
        pytest.raises(SystemExit) as exc,
    ):
        proxy._point_vobiz_number(ANSWER, HANGUP)

    assert exc.value.code == 1
    assert calls == [("GET", "/numbers?search=%2B917700900123")]
    assert "not found on this account" in capsys.readouterr().err


def test_app_list_is_paged_until_the_app_is_found():
    """
    Scenario: The account has more than one page of applications
        Given the first page of 100 applications does not contain ours
          And the second page does
         When the number is pointed at the proxy
         Then the second page is requested
          And the existing application is updated, not duplicated

    Purpose:
        Reading only the first page would create a new application on
        every run for an account with more than 100 of them.
    """
    calls = []
    page_one = [{"app_id": str(i), "app_name": f"other-{i}"} for i in range(100)]
    ours = {"app_id": "777", "app_name": APP_NAME}

    def request(method, path, body=None):
        calls.append((method, path, body))
        if path.startswith("/numbers?"):
            return {"items": [{"e164": NUMBER}]}
        if path == "/Application/?limit=100&offset=0":
            return {"objects": page_one, "meta": {"next": "/next", "total_count": 101}}
        if path == "/Application/?limit=100&offset=100":
            return {"objects": [ours], "meta": {"next": None, "total_count": 101}}
        return {"message": "ok"}

    with patch("proxy._vobiz_request", side_effect=request):
        proxy._point_vobiz_number(ANSWER, HANGUP)

    assert not any(c[:2] == ("POST", "/Application/") for c in calls)
    assert any(c[:2] == ("POST", "/Application/777/") for c in calls)


def test_missing_app_id_is_a_clear_error():
    """
    Scenario: Vobiz creates the application but returns no app_id
        Given the create response has no app_id
         When the number is pointed at the proxy
         Then a VobizAPIError names the application

    Purpose:
        A bare KeyError would escape main() as a stack trace.
    """

    def request(method, path, body=None):
        if path.startswith("/numbers?"):
            return {"items": [{"e164": NUMBER}]}
        if path.startswith("/Application/?"):
            return {"objects": [], "meta": {"next": None}}
        return {"message": "created"}

    with (
        patch("proxy._vobiz_request", side_effect=request),
        pytest.raises(proxy.VobizAPIError, match=APP_NAME),
    ):
        proxy._point_vobiz_number(ANSWER, HANGUP)
