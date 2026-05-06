"""FastAPI server that serves the browser frontend and a LiveKit access token."""

import os
import uuid
from pathlib import Path

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from livekit.api import AccessToken, VideoGrants

load_dotenv()

LIVEKIT_URL = os.environ["LIVEKIT_URL"]
LIVEKIT_API_KEY = os.environ["LIVEKIT_API_KEY"]
LIVEKIT_API_SECRET = os.environ["LIVEKIT_API_SECRET"]
ROOM_NAME = "alphanumerics-room"

ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"

app = FastAPI()


@app.get("/")
def index() -> FileResponse:
    return FileResponse(ASSETS_DIR / "index.html")


@app.get("/token")
def get_token() -> JSONResponse:
    identity = f"user-{uuid.uuid4().hex[:8]}"
    token = (
        AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(identity)
        .with_name("Browser User")
        .with_grants(VideoGrants(room_join=True, room=ROOM_NAME))
        .to_jwt()
    )
    return JSONResponse({"token": token, "url": LIVEKIT_URL, "room": ROOM_NAME})


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
