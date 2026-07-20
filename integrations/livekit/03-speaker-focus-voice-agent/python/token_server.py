"""
Speaker Focus demo — local token + dispatch server for the frontend.

Serves LiveKit room tokens at http://127.0.0.1:8790/token AND explicitly
dispatches the "speaker-focus" agent into the room (deterministic — no reliance
on automatic dispatch). The browser joins the room the agent was dispatched to.

Run:  .venv\\Scripts\\python token_server.py
"""

import asyncio
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from dotenv import load_dotenv
from livekit import api

HERE = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(HERE, ".env"))
load_dotenv(os.path.join(os.path.dirname(HERE), ".env"))  # .env at the example root also works

HOST, PORT = "127.0.0.1", 8790
AGENT_NAME = "speaker-focus"


async def ensure_dispatch(room: str) -> str:
    """Dispatch the agent unless a LIVE agent is already in the room.

    Checks for an actual agent participant (kind AGENT), not just a dispatch
    record — a stale dispatch whose agent has died would otherwise leave the
    room stuck on "waiting for agent" forever.
    """
    lk = api.LiveKitAPI(os.getenv("LIVEKIT_URL"), os.getenv("LIVEKIT_API_KEY"), os.getenv("LIVEKIT_API_SECRET"))
    try:
        try:
            parts = await lk.room.list_participants(api.ListParticipantsRequest(room=room))
            if any(p.kind == 4 or p.identity.startswith("agent") for p in parts.participants):
                return "agent-present"
        except Exception:
            pass  # room may not exist yet — dispatch will create it
        await lk.agent_dispatch.create_dispatch(api.CreateAgentDispatchRequest(agent_name=AGENT_NAME, room=room))
        return "dispatched"
    finally:
        await lk.aclose()


class TokenHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        if u.path != "/token":
            self.send_response(404)
            self.end_headers()
            return
        q = parse_qs(u.query)
        room = q.get("room", ["speaker-focus-demo"])[0]
        identity = q.get("identity", ["viewer"])[0]

        try:
            status = asyncio.run(ensure_dispatch(room))
        except Exception as e:
            status = f"dispatch-error: {e}"

        token = (
            api.AccessToken(os.getenv("LIVEKIT_API_KEY"), os.getenv("LIVEKIT_API_SECRET"))
            .with_identity(identity)
            .with_grants(api.VideoGrants(room_join=True, room=room))
            .to_jwt()
        )
        body = json.dumps({"url": os.getenv("LIVEKIT_URL"), "token": token, "dispatch": status}).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")  # frontend runs on :8748
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("[token]", fmt % args)


if __name__ == "__main__":
    for var in ("LIVEKIT_URL", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET"):
        if not os.getenv(var):
            raise SystemExit(f"{var} not set in agent/.env")
    print(
        f"Token + dispatch server on http://{HOST}:{PORT}/token -- dispatches agent '{AGENT_NAME}' into the room the frontend asks for"
    )
    ThreadingHTTPServer((HOST, PORT), TokenHandler).serve_forever()
