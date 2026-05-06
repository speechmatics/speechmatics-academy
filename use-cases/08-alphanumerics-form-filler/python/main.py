#!/usr/bin/env python3
"""Voice agent that listens to spoken alphanumeric details and fills a web form via LiveKit RPC."""

import json

from dotenv import load_dotenv
from livekit import agents
from livekit.agents import (
    Agent,
    AgentSession,
    RoomInputOptions,
    RunContext,
    function_tool,
)
from livekit.plugins import openai, silero, speechmatics
from livekit.plugins.speechmatics import TurnDetectionMode

load_dotenv()


class FormFillerAgent(Agent):
    def __init__(self) -> None:
        super().__init__(
            instructions=(
                "You are a helpful voice assistant collecting form details. "
                "When the user provides any of the following, call fill_form_field with the "
                "correct field name and value: first_name, last_name, email, phone, "
                "licence_plate, account_number, post_code, city. "
                "Ask for each field in turn if not yet provided. Be concise and friendly. "
                "Ask for clarification when needed before making tool calls. "
                "Be aware of spoken form (eye vs I, etc). "
                "For numeric fields (phone, account_number, post_code), capture the digits as "
                "one continuous string with no spaces, commas, dashes, or word groupings — "
                "e.g. 'one two three four five' becomes 12345, never 12,345 or "
                "'twelve thousand three hundred forty-five'. "
                "When reading any number back to the user to confirm, speak each digit "
                "individually as a single entity (e.g. 'one, two, three, four, five'), "
                "never as grouped numerals like 'twelve thousand'."
            )
        )

    @function_tool
    async def fill_form_field(self, ctx: RunContext, field: str, value: str) -> str:
        """Fill a form field. field must be one of: first_name, last_name, email, phone, licence_plate, account_number, post_code, city."""
        room = ctx.session.room_io.room
        participant = ctx.session.room_io.linked_participant
        if not participant:
            return "No participant found to send RPC to."

        await room.local_participant.perform_rpc(
            destination_identity=participant.identity,
            method="fillFormField",
            payload=json.dumps({"field": field, "value": value}),
        )
        return f"Filled {field}: {value}"


async def entrypoint(ctx: agents.JobContext) -> None:
    await ctx.connect()

    stt = speechmatics.STT(turn_detection_mode=TurnDetectionMode.SMART_TURN)
    llm = openai.LLM(model="gpt-4o-mini")
    tts = speechmatics.TTS()
    vad = silero.VAD.load()

    session = AgentSession(stt=stt, llm=llm, tts=tts, vad=vad)

    await session.start(
        room=ctx.room,
        agent=FormFillerAgent(),
        room_input_options=RoomInputOptions(),
    )

    await session.generate_reply(
        instructions=(
            "Say a short hello and ask the user to provide their details and you will "
            "fill in the form as they go. Keep responses super short as you are a voice bot."
        )
    )


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
