"""VAPI Voice Assistant with Speechmatics STT."""

import os
import re
import sys

from dotenv import load_dotenv
from vapi import Vapi
from vapi.types import SpeechmaticsTranscriber, OpenAiModel, ElevenLabsVoice

load_dotenv()

UUID_PATTERN = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)


def get_client():
    """Get authenticated VAPI client."""
    token = os.getenv("VAPI_API_KEY")
    if not token:
        print("Error: Set VAPI_API_KEY in .env")
        return None
    return Vapi(token=token)


def create_assistant():
    """Create a VAPI assistant with Speechmatics STT."""
    client = get_client()
    if not client:
        return None

    assistant = client.assistants.create(
        name="Speechmatics Assistant",
        transcriber=SpeechmaticsTranscriber(
            provider="speechmatics",
            model="default",
            language="en",
            operating_point="enhanced",
            region="us",
            enable_diarization=True,
            max_speakers=2,
            speaker_labels=["SuperAgent", "Client"],
            enable_partials=True,
            enable_punctuation=True,
            enable_capitalization=True,
            remove_disfluencies=True,
            end_of_turn_sensitivity=0.5,
            custom_vocabulary=[
                {"content": "Speechmatics", "sounds_like": ["speech matics", "speech mattics"]},
                {"content": "Vapi", "sounds_like": ["vappy", "vahpee", "vaypee", "v a p i", "vap ee"]},
            ],
        ),
        model=OpenAiModel(
            provider="openai",
            model="gpt-4o-mini",
            messages=[{
                "role": "system",
                "content": "You are a helpful voice assistant. Keep responses brief and conversational.",
            }],
        ),
        voice=ElevenLabsVoice(provider="11labs", voice_id="21m00Tcm4TlvDq8ikWAM"),
        first_message="Hello! How can I help you today?",
        end_call_message="Goodbye!",
    )

    print(f"Created: {assistant.name} ({assistant.id})")
    print(f"Test at: https://dashboard.vapi.ai/")
    return assistant


def list_assistants():
    """List all VAPI assistants."""
    client = get_client()
    if not client:
        return

    assistants = client.assistants.list()
    print(f"\n{len(assistants)} assistant(s):\n")
    for a in assistants:
        provider = getattr(getattr(a, "transcriber", None), "provider", "unknown")
        print(f"  {a.name} ({a.id}) - {provider}")


def get_assistant(assistant_id: str):
    """Get assistant details."""
    if not UUID_PATTERN.match(assistant_id):
        print(f"Error: Invalid UUID. Run 'list' to see IDs.")
        return None

    client = get_client()
    if not client:
        return None

    a = client.assistants.get(id=assistant_id)
    t = a.transcriber
    print(f"\n{a.name} ({a.id})")
    if t:
        print(f"  Transcriber: {getattr(t, 'provider', '?')} | {getattr(t, 'language', '?')} | {getattr(t, 'operating_point', '?')}")
    return a


def delete_assistant(assistant_id: str):
    """Delete an assistant."""
    if not UUID_PATTERN.match(assistant_id):
        print(f"Error: Invalid UUID. Run 'list' to see IDs.")
        return

    client = get_client()
    if not client:
        return

    client.assistants.delete(id=assistant_id)
    print(f"Deleted: {assistant_id}")


if __name__ == "__main__":
    commands = {
        "list": lambda: list_assistants(),
        "get": lambda: get_assistant(sys.argv[2]) if len(sys.argv) > 2 else print("Usage: get <id>"),
        "delete": lambda: delete_assistant(sys.argv[2]) if len(sys.argv) > 2 else print("Usage: delete <id>"),
    }

    if len(sys.argv) > 1 and sys.argv[1] in commands:
        commands[sys.argv[1]]()
    elif len(sys.argv) == 1:
        create_assistant()
    else:
        print("Usage: python main.py [list|get <id>|delete <id>]")
