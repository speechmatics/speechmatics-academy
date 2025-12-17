#!/usr/bin/env python3
"""
AI Receptionist - LiveKit + Speechmatics + Google Calendar

An intelligent receptionist that handles inbound calls, books appointments
to Google Calendar, and answers business questions.
"""

from pathlib import Path

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import Agent, AgentSession, RoomInputOptions
from livekit.plugins import openai, silero, speechmatics

from calendar_tools import CALENDAR_TOOLS

load_dotenv()


def load_agent_prompt() -> str:
    """Load the receptionist prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a friendly receptionist. Help callers book appointments."


async def entrypoint(ctx: agents.JobContext):
    """Main entrypoint for the AI receptionist."""
    await ctx.connect()

    # Speech-to-Text: Speechmatics with custom vocabulary
    stt = speechmatics.STT(
        enable_diarization=True,
        operating_point="enhanced",
        enable_partials=True,
        focus_speakers=["S1"],
        end_of_utterance_silence_trigger=0.5,
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
        max_delay=0.7,
        additional_vocab=[
            # Days of the week
            speechmatics.AdditionalVocabEntry(content="Monday", sounds_like=["Mon", "mon day"]),
            speechmatics.AdditionalVocabEntry(content="Tuesday", sounds_like=["Tues", "tues day", "chews day"]),
            speechmatics.AdditionalVocabEntry(content="Wednesday", sounds_like=["Wed", "wens day", "wed nes day"]),
            speechmatics.AdditionalVocabEntry(content="Thursday", sounds_like=["Thurs", "thurs day"]),
            speechmatics.AdditionalVocabEntry(content="Friday", sounds_like=["Fri", "fry day"]),
            speechmatics.AdditionalVocabEntry(content="Saturday", sounds_like=["Sat", "sat er day"]),
            speechmatics.AdditionalVocabEntry(content="Sunday", sounds_like=["Sun", "sun day"]),
            # Services offered
            speechmatics.AdditionalVocabEntry(content="Swedish Massage", sounds_like=["swedish", "sweedish massage", "swedish mas sage"]),
            speechmatics.AdditionalVocabEntry(content="Deep Tissue Massage", sounds_like=["deep tissue", "deep tis sue", "deep tissue mas sage"]),
            speechmatics.AdditionalVocabEntry(content="Hot Stone Therapy", sounds_like=["hot stone", "hot stones", "hot stone thera py"]),
            speechmatics.AdditionalVocabEntry(content="Sports Massage", sounds_like=["sports", "sport massage", "sports mas sage"]),
            # Appointment terms
            speechmatics.AdditionalVocabEntry(content="consultation", sounds_like=["consult", "consul tation"]),
            speechmatics.AdditionalVocabEntry(content="follow-up", sounds_like=["follow up", "followup"]),
            speechmatics.AdditionalVocabEntry(content="walk-in", sounds_like=["walk in", "walkin"]),
            speechmatics.AdditionalVocabEntry(content="AM", sounds_like=["A M", "a.m.", "in the morning"]),
            speechmatics.AdditionalVocabEntry(content="PM", sounds_like=["P M", "p.m.", "in the afternoon", "in the evening"]),
        ],
    )

    # Language Model: OpenAI with function calling
    llm = openai.LLM(model="gpt-4o")

    # Text-to-Speech: Speechmatics
    tts = speechmatics.TTS(voice="megan")

    # Voice Activity Detection: Silero
    vad = silero.VAD.load()

    # Create agent with calendar tools
    receptionist = Agent(
        instructions=load_agent_prompt(),
        tools=CALENDAR_TOOLS,
    )

    # Create and start session
    session = AgentSession(
        stt=stt,
        llm=llm,
        tts=tts,
        vad=vad,
    )

    await session.start(
        room=ctx.room,
        agent=receptionist,
        room_input_options=RoomInputOptions(),
    )

    # Initial greeting
    await session.generate_reply(
        instructions="Greet the caller warmly, introduce yourself as the receptionist, and ask how you can help them today."
    )


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
