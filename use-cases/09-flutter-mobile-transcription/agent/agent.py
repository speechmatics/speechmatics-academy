"""EveryVoice's named LiveKit agent; all model access uses LiveKit Inference."""

from __future__ import annotations

from functools import partial

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import Agent, AgentServer, AgentSession, TurnHandlingOptions, inference

from config import Settings, parse_personality


def create_assistant(settings: Settings, metadata: str | None = None) -> Agent:
    personality = parse_personality(metadata).personality.strip()
    instructions = settings.instructions
    if personality:
        instructions += f"\n\nUser communication preferences:\n{personality}"
    return Agent(instructions=instructions)


def create_session(settings: Settings) -> AgentSession:
    credentials = {
        "api_key": settings.livekit_api_key,
        "api_secret": settings.livekit_api_secret,
    }
    return AgentSession(
        stt=inference.STT(
            model="speechmatics/linden-1",
            language=settings.stt_language,
            **credentials,
        ),
        llm=inference.LLM(model=settings.llm_model, **credentials),
        tts=inference.TTS(model=settings.tts_model, voice=settings.tts_voice, **credentials),
        # Linden closes STT turns on the server. The session's bundled VAD still
        # provides responsive interruption detection; no custom phone VAD exists.
        turn_handling=TurnHandlingOptions(turn_detection="stt"),
    )


async def entrypoint(ctx: agents.JobContext, *, settings: Settings) -> None:
    """Module-level callable so Python can serialize it for spawned Cloud jobs."""
    assistant = create_assistant(settings, ctx.job.metadata)
    session = create_session(settings)
    ctx.add_shutdown_callback(session.aclose)
    await session.start(room=ctx.room, agent=assistant)
    await session.generate_reply(instructions="Greet the user briefly and ask how you can help.")


def create_server(settings: Settings) -> AgentServer:
    server = AgentServer()
    server.rtc_session(partial(entrypoint, settings=settings), agent_name=settings.agent_name)
    return server


load_dotenv(".env.local")
# The current `lk agent` CLI imports the module to discover this server.
server = create_server(Settings.from_env())


if __name__ == "__main__":
    agents.cli.run_app(server)
