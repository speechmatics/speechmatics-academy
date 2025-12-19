#!/usr/bin/env python3
"""
Santa's Workshop Hotline - LiveKit + Speechmatics STT + ElevenLabs TTS + OpenAI

"""

from pathlib import Path

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import Agent, AgentSession, RoomInputOptions
from livekit.plugins import openai, silero, speechmatics, elevenlabs

load_dotenv()


def load_agent_prompt() -> str:
    """Load Santa's personality from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are Santa Claus. Help adults reconnect with Christmas magic."


async def entrypoint(ctx: agents.JobContext):
    """Main entrypoint for Santa's Workshop Hotline."""
    await ctx.connect()

    # Speech-to-Text: Speechmatics with Christmas vocabulary
    stt = speechmatics.STT(
        enable_diarization=True,
        operating_point="enhanced",
        enable_partials=True,
        focus_speakers=["S1"],
        end_of_utterance_silence_trigger=0.6,
        max_delay=0.7,
        additional_vocab=[
            # Christmas terms
            speechmatics.AdditionalVocabEntry(content="Santa Claus", sounds_like=["Santa", "santa clause", "Father Christmas"]),
            speechmatics.AdditionalVocabEntry(content="Christmas", sounds_like=["Xmas", "chris mas", "kris mas"]),
            speechmatics.AdditionalVocabEntry(content="Merry Christmas", sounds_like=["merry xmas", "merry chris mas"]),
            speechmatics.AdditionalVocabEntry(content="Nice List", sounds_like=["nice list", "the nice list"]),
            speechmatics.AdditionalVocabEntry(content="Naughty List", sounds_like=["naughty list", "the naughty list"]),
        ],
    )

    # Language Model: OpenAI
    llm = openai.LLM(model="gpt-4o-mini")

    # Text-to-Speech: ElevenLabs with Santa voice
    # Voice ID: 6oJyGTjYmfuGXhTV8Fhg (custom Santa voice)
    # Model: eleven_multilingual_v2 for highest quality
    tts = elevenlabs.TTS(
        voice_id="6oJyGTjYmfuGXhTV8Fhg",
        model="eleven_multilingual_v2",
        voice_settings=elevenlabs.VoiceSettings(
            stability=0.4,           # Low for animated, lively variation
            similarity_boost=0.8,    # Good voice match
            style=0.9,               # High for maximum jolly expressiveness
            use_speaker_boost=True,
            speed=0.9                # Slightly faster for energy
        ),
    )

    # Voice Activity Detection: Silero
    vad = silero.VAD.load()

    # Create Santa agent
    santa = Agent(
        instructions=load_agent_prompt(),
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
        agent=santa,
        room_input_options=RoomInputOptions(),
    )

    # Santa's magical greeting - use say() for instant response (skips LLM)
    await session.say("Well, well, well... it's been a few years! What's your name?")

if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
