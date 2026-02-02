#!/usr/bin/env python3
"""
Telephony Voice Assistant - LiveKit SIP + Twilio + Speechmatics Integration

A conversational voice assistant for phone calls using:
- LiveKit SIP (Telephony via Twilio)
- Speechmatics STT (Speech-to-Text)
- OpenAI LLM (Language Model)
- Speechmatics TTS (Text-to-Speech)

"""

from pathlib import Path

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import openai, silero, speechmatics

load_dotenv()


def load_agent_prompt() -> str:
    """Load the agent system prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a helpful voice assistant. Be concise and friendly."


class VoiceAssistant(Agent):
    """Voice assistant agent with Speechmatics STT and TTS for telephony."""

    def __init__(self) -> None:
        super().__init__(instructions=load_agent_prompt())


async def entrypoint(ctx: agents.JobContext):
    """
    Main entrypoint for the telephony voice assistant.

    Pipeline flow:
    1. Twilio Phone Call -> LiveKit SIP -> LiveKit Room
    2. Speechmatics STT -> Transcribes speech to text
    3. OpenAI LLM -> Generates response
    4. Speechmatics TTS -> Converts response to speech
    5. LiveKit Room -> LiveKit SIP -> Twilio -> Phone Call
    """
    await ctx.connect()

    # Speech-to-Text: Speechmatics
    stt = speechmatics.STT(
        turn_detection_mode=speechmatics.TurnDetectionMode.EXTERNAL,
    )

    # Language Model: OpenAI
    llm = openai.LLM(model="gpt-4o-mini")

    # Text-to-Speech: Speechmatics
    # Available voices: sarah (UK female), theo (UK male), megan (US female)
    tts = speechmatics.TTS(voice="megan")

    # Voice Activity Detection: Silero
    vad = silero.VAD.load()

    # Create Agent Session
    session = AgentSession(stt=stt, llm=llm, tts=tts, vad=vad, turn_detection="vad")

    # Start Session
    await session.start(
        room=ctx.room,
        agent=VoiceAssistant(),
        room_input_options=RoomInputOptions(),
    )

    # Trigger end of turn from the VAD
    @session.on("user_state_changed")
    def on_user_state(state):
        if state.new_state == "listening" and state.old_state == "speaking":
            stt.finalize()

    # Send Initial Greeting
    await session.generate_reply(
        instructions="Say a short hello and ask how you can help."
    )


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
