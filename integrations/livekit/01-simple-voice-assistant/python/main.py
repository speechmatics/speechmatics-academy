#!/usr/bin/env python3
"""
Simple Voice Assistant - LiveKit Agents + Speechmatics Integration

A conversational voice assistant using:
- Speechmatics STT (Speech-to-Text)
- OpenAI LLM (Language Model)
- ElevenLabs TTS (Text-to-Speech)
- LiveKit WebRTC (Real-time Communication)

"""

from pathlib import Path

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import openai, silero, speechmatics, elevenlabs

load_dotenv()


def load_agent_prompt() -> str:
    """Load the agent system prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a helpful voice assistant. Be concise and friendly."


class VoiceAssistant(Agent):
    """Voice assistant agent with Speechmatics STT."""

    def __init__(self) -> None:
        super().__init__(instructions=load_agent_prompt())


async def entrypoint(ctx: agents.JobContext):
    """
    Main entrypoint for the voice assistant.

    Pipeline flow:
    1. LiveKit Room -> WebRTC audio input from user
    2. Speechmatics STT -> Transcribes speech to text
    3. OpenAI LLM -> Generates response
    4. ElevenLabs TTS -> Converts response to speech
    5. LiveKit Room -> WebRTC audio output to user
    """
    await ctx.connect()

    # Speech-to-Text: Speechmatics
    stt = speechmatics.STT(
        turn_detection_mode=speechmatics.TurnDetectionMode.EXTERNAL,
        enable_diarization=True,
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
        speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
        focus_speakers=["S1"],
    )

    # Language Model: OpenAI
    llm = openai.LLM(model="gpt-4o-mini")

    # Text-to-Speech: ElevenLabs
    tts = elevenlabs.TTS(voice_id="21m00Tcm4TlvDq8ikWAM")  # Rachel

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
