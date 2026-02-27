#!/usr/bin/env python3
"""
Voice Assistant with Speaker Identification - LiveKit Agents + Speechmatics

Speechmatics handles speaker identification natively via voiceprints:
1. First session: speakers labeled S1, S2 by diarization
2. Voiceprints auto-captured via GET_SPEAKERS and saved to speakers.json
3. Next session: returning speakers recognized by their saved voiceprint

To assign a name, edit the "label" field in speakers.json after first run.

Usage:
    python main.py console
"""

import asyncio
import json
import re
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import AgentSession, Agent, RoomInputOptions
from livekit.plugins import openai, silero, speechmatics, elevenlabs
from livekit.plugins.speechmatics import TurnDetectionMode, SpeakerIdentifier

load_dotenv(Path(__file__).parent.parent / ".env")

SPEAKERS_FILE = Path(__file__).parent / "speakers.json"
RESERVED_LABEL = re.compile(r"^S\d+$")


def load_known_speakers() -> list[SpeakerIdentifier]:
    """Load previously enrolled speakers from disk."""
    if not SPEAKERS_FILE.exists():
        return []

    with open(SPEAKERS_FILE) as f:
        data = json.load(f)

    return [
        SpeakerIdentifier(label=entry["label"], speaker_identifiers=entry["speaker_identifiers"])
        for entry in data
        if entry.get("label") and entry.get("speaker_identifiers")
        and not RESERVED_LABEL.match(entry["label"])
    ]


def save_speakers(raw_speakers: list[Any]) -> None:
    """Persist speakers from GET_SPEAKERS result to disk.

    Reserved labels like S1/S2 are renamed to Speaker_1/Speaker_2 so
    they can be loaded as known_speakers without server rejection.
    Edit the label field to assign a real name.
    """
    data = []
    for speaker in raw_speakers:
        if isinstance(speaker, dict):
            label, ids = speaker.get("label", ""), speaker.get("speaker_identifiers", [])
        else:
            label, ids = speaker.label, speaker.speaker_identifiers
        if label and ids:
            if RESERVED_LABEL.match(label):
                label = f"Speaker_{label[1:]}"
            data.append({"label": label, "speaker_identifiers": ids})

    if data:
        with open(SPEAKERS_FILE, "w") as f:
            json.dump(data, f, indent=2)


def load_agent_prompt() -> str:
    """Load the agent system prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a helpful voice assistant. Be concise and friendly."


class VoiceAssistant(Agent):
    def __init__(self) -> None:
        super().__init__(instructions=load_agent_prompt())


async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()

    known_speakers = load_known_speakers()

    stt = speechmatics.STT(
        turn_detection_mode=TurnDetectionMode.SMART_TURN,
        enable_diarization=True,
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
        speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
        focus_speakers=["S1"],
        known_speakers=known_speakers,
    )

    llm = openai.LLM(model="gpt-4o-mini")
    tts = elevenlabs.TTS(voice_id="21m00Tcm4TlvDq8ikWAM")
    vad = silero.VAD.load()

    session = AgentSession(stt=stt, llm=llm, tts=tts, vad=vad)

    await session.start(
        room=ctx.room,
        agent=VoiceAssistant(),
        room_input_options=RoomInputOptions(),
    )

    if known_speakers:
        names = ", ".join(s.label for s in known_speakers)
        await session.generate_reply(
            instructions=f"Greet the user. You recognize: {names}. Welcome them back by name. Be brief."
        )
    else:
        await session.generate_reply(
            instructions="Say a short hello and ask how you can help."
        )

    # Capture voiceprints in background and save immediately
    async def capture_voiceprints():
        await asyncio.sleep(15)
        while True:
            try:
                result = await stt.get_speaker_ids()
                if result:
                    save_speakers(result)
            except Exception:
                pass
            await asyncio.sleep(30)

    asyncio.create_task(capture_voiceprints())


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(entrypoint_fnc=entrypoint),
    )
