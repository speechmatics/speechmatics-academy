"""Authenticated, single-agent token endpoint for the EveryVoice mobile app."""

from __future__ import annotations

import secrets
from datetime import timedelta
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from livekit import api
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from config import Settings, parse_personality


class AgentDispatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    agent_name: str | None = None
    metadata: str | None = None
    deployment: None = None


class RoomConfigRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    agents: list[AgentDispatchRequest] | None = Field(default=None, max_length=1)


class TokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    # Standard client SDKs include these optional keys as null. The server owns
    # their actual values, so requests cannot join another user's room.
    room_name: None = None
    participant_identity: None = None
    participant_name: None = None
    participant_metadata: None = None
    participant_attributes: None = None
    room_config: RoomConfigRequest | None = None


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    app = FastAPI(title="EveryVoice token issuer", docs_url=None, redoc_url=None, openapi_url=None)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/token", status_code=201)
    async def token(request: Request, authorization: str | None = Header(default=None)):
        if not settings.app_token:
            raise HTTPException(503, "Token service is not configured")
        expected = f"Bearer {settings.app_token}".encode()
        if not secrets.compare_digest((authorization or "").encode("utf-8"), expected):
            raise HTTPException(401, "Unauthorized", headers={"WWW-Authenticate": "Bearer"})
        if not all((settings.livekit_url, settings.livekit_api_key, settings.livekit_api_secret)):
            raise HTTPException(503, "Token service is not configured")

        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > 65536:
                raise HTTPException(413, "Request body is too large")
        try:
            payload = TokenRequest.model_validate_json(bytes(body))
            dispatches = payload.room_config.agents if payload.room_config else None
            dispatch = dispatches[0] if dispatches else AgentDispatchRequest()
            if dispatch.agent_name not in (None, settings.agent_name):
                raise ValueError("Different agent requested")
            metadata = parse_personality(dispatch.metadata).model_dump_json()
        except (ValidationError, ValueError):
            # Do not echo user metadata or credentials in error responses.
            raise HTTPException(422, "Invalid session request") from None

        room_name = f"everyvoice-{uuid4().hex}"
        participant_identity = f"user-{uuid4().hex}"
        participant_token = (
            api.AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
            .with_identity(participant_identity)
            .with_ttl(timedelta(minutes=10))
            .with_grants(
                api.VideoGrants(
                    room_join=True,
                    room=room_name,
                    can_publish=True,
                    can_subscribe=True,
                    can_publish_data=True,
                    can_publish_sources=["microphone"],
                )
            )
            .with_room_config(
                api.RoomConfiguration(
                    agents=[
                        api.RoomAgentDispatch(
                            agent_name=settings.agent_name,
                            metadata=metadata,
                        )
                    ]
                )
            )
            .to_jwt()
        )
        return {"server_url": settings.livekit_url, "participant_token": participant_token}

    return app


load_dotenv(".env.local")
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
