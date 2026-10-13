import asyncio
import json
import time

import httpx
import jwt
import pytest

APP_TOKEN = "test-app-token-with-at-least-thirty-two-characters"
SIGNING_SECRET = "test-signing-secret-with-at-least-thirty-two-characters"
AUTH = {"Authorization": f"Bearer {APP_TOKEN}"}


class AppClient:
    """Exercise real ASGI routes without Starlette's deprecated httpx TestClient."""

    def __init__(self, app):
        self.app = app

    def request(self, method, url, **kwargs):
        async def send():
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=self.app), base_url="http://testserver"
            ) as client:
                return await client.request(method, url, **kwargs)

        return asyncio.run(send())

    def post(self, url, **kwargs):
        return self.request("POST", url, **kwargs)

    def get(self, url, **kwargs):
        return self.request("GET", url, **kwargs)


def make_client(**overrides):
    from config import Settings
    from token_server import create_app

    values = {
        "livekit_url": "wss://test.livekit.cloud",
        "livekit_api_key": "test-api-key",
        "livekit_api_secret": SIGNING_SECRET,
        "app_token": APP_TOKEN,
    }
    values.update(overrides)
    return AppClient(create_app(Settings(**values)))


@pytest.mark.parametrize(
    "headers", [{}, {"Authorization": "Bearer wrong"}, {"Authorization": "Basic abc"}]
)
def test_unauthenticated_requests_never_receive_tokens(headers):
    response = make_client().post("/token", json={}, headers=headers)
    assert response.status_code == 401
    assert "participant_token" not in response.json()


def test_missing_auth_configuration_fails_closed():
    response = make_client(app_token="").post("/token", json={}, headers=AUTH)
    assert response.status_code == 503


def test_missing_signing_configuration_never_issues_token():
    response = make_client(livekit_api_secret="").post("/token", json={}, headers=AUTH)
    assert response.status_code == 503


def test_tokens_are_signed_scoped_unique_and_short_lived():
    client = make_client()
    tokens = []
    for _ in range(2):
        response = client.post("/token", json={}, headers=AUTH)
        assert response.status_code == 201
        assert set(response.json()) == {"server_url", "participant_token"}
        assert response.json()["server_url"] == "wss://test.livekit.cloud"
        claims = jwt.decode(
            response.json()["participant_token"], SIGNING_SECRET, algorithms=["HS256"]
        )
        assert claims["iss"] == "test-api-key"
        assert claims["video"]["roomJoin"] is True
        assert claims["video"]["canPublish"] is True
        assert claims["video"]["canSubscribe"] is True
        assert claims["video"]["canPublishData"] is True
        assert claims["video"]["canPublishSources"] == ["microphone"]
        assert not claims["video"].get("roomAdmin", False)
        assert claims["roomConfig"]["agents"][0]["agentName"] == "everyvoice-agent"
        assert 595 <= claims["exp"] - time.time() <= 601
        tokens.append(claims)
    assert tokens[0]["sub"] != tokens[1]["sub"]
    assert tokens[0]["video"]["room"] != tokens[1]["video"]["room"]


def test_standard_flutter_request_preserves_only_validated_personality():
    request = {
        "room_name": None,
        "participant_identity": None,
        "participant_name": None,
        "participant_metadata": None,
        "participant_attributes": None,
        "room_config": {
            "agents": [
                {
                    "agent_name": "everyvoice-agent",
                    "metadata": json.dumps({"personality": "Speak gently, in short sentences."}),
                }
            ]
        },
    }
    response = make_client().post("/token", json=request, headers=AUTH)
    assert response.status_code == 201
    claims = jwt.decode(response.json()["participant_token"], SIGNING_SECRET, algorithms=["HS256"])
    assert json.loads(claims["roomConfig"]["agents"][0]["metadata"]) == {
        "personality": "Speak gently, in short sentences."
    }


@pytest.mark.parametrize(
    "payload",
    [
        {"room_name": "someone-elses-room"},
        {"participant_identity": "admin"},
        {"participant_name": "arbitrary"},
        {"participant_metadata": "untrusted"},
        {"participant_attributes": {"admin": "true"}},
        {"unexpected": "value"},
        {"room_config": {"agents": [{"agent_name": "another-agent"}]}},
        {"room_config": {"agents": [{"agent_name": "everyvoice-agent", "deployment": "other"}]}},
        {"room_config": {"agents": [{}, {}]}},
        {"room_config": {"agents": [{"metadata": "not json"}]}},
        {"room_config": {"agents": [{"metadata": json.dumps({"personality": "x" * 12001})}]}},
        {"room_config": {"agents": [{"metadata": json.dumps({"personality": 42})}]}},
        {"room_config": {"agents": [{"metadata": json.dumps({"instructions": "unexpected"})}]}},
    ],
)
def test_untrusted_request_fields_are_rejected(payload):
    response = make_client().post("/token", json=payload, headers=AUTH)
    assert response.status_code == 422
    assert "participant_token" not in response.json()


def test_malformed_json_and_oversize_body_are_rejected():
    client = make_client()
    assert client.post("/token", content="{", headers=AUTH).status_code == 422
    assert client.post("/token", content="x" * 65537, headers=AUTH).status_code == 413


def test_health_discloses_no_configuration_or_secrets():
    response = make_client().get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
