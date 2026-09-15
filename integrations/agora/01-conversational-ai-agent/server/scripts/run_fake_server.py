import os
import sys

import uvicorn


class FakeAgent:
    def __init__(self):
        self.started_agent_ids = set()

    async def start(self, channel_name: str, agent_uid: int, user_uid: int, output_audio_codec=None):
        if not channel_name or agent_uid <= 0 or user_uid <= 0:
            raise ValueError("channel_name, agent_uid, and user_uid must be valid")

        agent_id = f"fake-agent-{agent_uid}"
        self.started_agent_ids.add(agent_id)
        return {
            "agent_id": agent_id,
            "channel_name": channel_name,
            "status": "started",
        }

    async def stop(self, agent_id: str):
        if not agent_id:
            raise ValueError("agent_id is required")
        self.started_agent_ids.discard(agent_id)


def main():
    server_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src_root = os.path.join(server_root, "src")
    if src_root not in sys.path:
        sys.path.insert(0, src_root)

    import server as server_module

    server_module.agent = FakeAgent()

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(server_module.app, host="127.0.0.1", port=port)


if __name__ == "__main__":
    main()
