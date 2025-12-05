"""
Voice Agent Speaker Focus & Speaker ID

Demonstrates:
1. Extracting speaker IDs for reuse across sessions
2. Speaker Focus - controlling which speakers drive the conversation

Speaker Focus Modes:
- IGNORE: Non-focused speakers are completely excluded from output
- RETAIN: Non-focused speakers appear as "passive" alongside focused speaker
"""

import asyncio
import json
import os
import sys

from dotenv import load_dotenv
from speechmatics.rt import Microphone, ClientMessageType, AuthenticationError
from speechmatics.voice import (
    VoiceAgentClient,
    VoiceAgentConfig,
    AgentServerMessageType,
    SpeakerIdentifier,
    SpeakerFocusConfig,
    SpeakerFocusMode,
)

load_dotenv()

# File to persist speaker identifiers between sessions
ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets")
SPEAKERS_FILE = os.path.join(ASSETS_DIR, "speakers.json")


def create_client(known_speakers=None, speaker_config=None):
    """Create a VoiceAgentClient with optional speaker configuration."""
    config_params = {
        "language": "en",
        "enable_diarization": True,  # Required for speaker identification
    }
    if known_speakers:
        config_params["known_speakers"] = known_speakers
    if speaker_config:
        config_params["speaker_config"] = speaker_config

    return VoiceAgentClient(
        api_key=os.getenv("SPEECHMATICS_API_KEY"),
        config=VoiceAgentConfig(**config_params),
    )


def load_speakers(required=False):
    """Load previously saved speaker IDs from file."""
    speakers = []
    if os.path.exists(SPEAKERS_FILE):
        with open(SPEAKERS_FILE, "r") as f:
            data = json.load(f)
            speakers = [
                SpeakerIdentifier(
                    label=s.get("label"),
                    speaker_identifiers=s.get("speaker_identifiers", []),
                )
                for s in data.get("speakers", [])
                if s.get("label") and s.get("speaker_identifiers")
            ]

    if required and not speakers:
        print("\nNo speakers found. Run option 1 first to create assets/speakers.json")
        return None

    return speakers


async def run_session(client, on_complete=None, stop_event=None):
    """Run a voice session - handles mic input, events, and cleanup."""
    @client.on(AgentServerMessageType.ADD_SEGMENT)
    def on_segment(message):
        # Handle transcribed speech segments
        for seg in message.get("segments", []):
            speaker = seg.get("speaker_id", "UU")
            text = seg.get("text", "")
            is_active = seg.get("is_active_speaker", True)
            # XML-style output: passive speakers wrapped in <PASSIVE> tags
            if is_active:
                print(f"<{speaker}>{text}</{speaker}>")
            else:
                print(f"<PASSIVE><{speaker}>{text}</{speaker}></PASSIVE>")

    @client.on(AgentServerMessageType.END_OF_TURN)
    def on_turn_end(message):
        # Handle end of speaker turn
        print("[END OF TURN]\n")
        if on_complete:
            on_complete()

    mic = Microphone(sample_rate=16000, chunk_size=320)
    if not mic.start():
        print("Error: PyAudio not installed. Run: pip install pyaudio")
        return

    try:
        await client.connect()
        # Continuously send audio to the server
        while True:
            if stop_event and stop_event.is_set():
                break
            await client.send_audio(await mic.read(320))
    except (KeyboardInterrupt, asyncio.CancelledError):
        pass
    finally:
        mic.stop()
        await client.disconnect()


async def example_extract_speaker_id():
    """
    Example 1: Extract speaker voice identifiers.

    Voice identifiers are acoustic fingerprints that can be saved and reused
    to recognize the same speaker in future sessions.
    """

    print("=" * 60)
    print("EXTRACT SPEAKER ID")
    print("=" * 60)

    # Get speaker name to save with their voice ID
    speaker_name = input("Enter your name: ").strip() or "Speaker"
    print(f"\nSpeak to extract voice identifier for '{speaker_name}'.")
    print("IDs will be saved after your first turn. Press Ctrl+C to exit.\n")

    speakers_saved = asyncio.Event()
    stop_session = asyncio.Event()
    client = create_client()

    @client.on(AgentServerMessageType.SPEAKERS_RESULT)
    def on_speakers_result(message):
        # Handle speaker identifiers returned by the server
        # Called in response to GET_SPEAKERS message
        speakers = message.get("speakers", [])
        if speakers:
            # Replace generic label (S1) with user-provided name
            speakers[0]["label"] = speaker_name

        # Save to file for use in future sessions
        with open(SPEAKERS_FILE, "w") as f:
            json.dump(message, f, indent=2)
        print("Saved to assets/speakers.json")
        for s in speakers:
            print(f"  {s.get('label')}: {len(s.get('speaker_identifiers', []))} identifiers")
        speakers_saved.set()
        stop_session.set()  # Auto-exit after saving

    def request_speakers():
        # Request speaker IDs from server after turn ends
        if not speakers_saved.is_set():
            print("Requesting speaker IDs...")
            # GET_SPEAKERS extracts voice identifiers from audio heard so far
            asyncio.create_task(client.send_message({"message": ClientMessageType.GET_SPEAKERS}))

    await run_session(client, on_complete=request_speakers, stop_event=stop_session)


async def example_speaker_focus_ignore():
    """
    Example 2: Speaker Focus with IGNORE mode.

    Only the focused speaker's speech is transcribed.
    All other speakers are completely filtered out.
    Use case: Voice assistant ignoring its own TTS playback.
    """
    speakers = load_speakers(required=True)
    if not speakers:
        return

    print("=" * 60)
    print("SPEAKER FOCUS (IGNORE MODE)")
    print("=" * 60)
    print(f"Loaded {len(speakers)} speaker(s) from assets/speakers.json")

    # First speaker is focused, others are ignored
    focus_label = speakers[0].label
    known = [speakers[0]]

    # Labels wrapped in double underscores are auto-ignored by the SDK
    if len(speakers) > 1:
        for s in speakers[1:]:
            known.append(SpeakerIdentifier(label="__IGNORED__", speaker_identifiers=s.speaker_identifiers))

    print(f"Focusing on: {focus_label}")
    print("Other speakers will be completely ignored. Press Ctrl+C to exit.\n")

    client = create_client(
        known_speakers=known,
        speaker_config=SpeakerFocusConfig(
            focus_speakers=[focus_label],
            focus_mode=SpeakerFocusMode.IGNORE,
        ),
    )
    await run_session(client)


async def example_speaker_focus_retain():
    """
    Example 3: Speaker Focus with RETAIN mode.

    The focused speaker drives the conversation (triggers VAD, turn detection).
    Other speakers still appear in output but marked as "passive".
    Use case: Meeting transcription prioritizing one speaker.
    """
    speakers = load_speakers(required=True)
    if not speakers:
        return

    print("=" * 60)
    print("SPEAKER FOCUS (RETAIN MODE)")
    print("=" * 60)
    print(f"Loaded {len(speakers)} speaker(s) from assets/speakers.json")

    focus_label = speakers[0].label
    print(f"Focusing on: {focus_label}")
    print("Other speakers will appear wrapped in <PASSIVE> tags. Press Ctrl+C to exit.\n")

    client = create_client(
        known_speakers=speakers,
        speaker_config=SpeakerFocusConfig(
            focus_speakers=[focus_label],
            focus_mode=SpeakerFocusMode.RETAIN,
        ),
    )
    await run_session(client)


async def main():
    # Check API key first for immediate feedback
    if not os.getenv("SPEECHMATICS_API_KEY"):
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    print("\n" + "=" * 60)
    print("VOICE AGENT: SPEAKER FOCUS & SPEAKER ID")
    print("=" * 60)
    print("\n1. Extract Speaker ID")
    print("2. Speaker Focus - IGNORE (non-focused speakers hidden)")
    print("3. Speaker Focus - RETAIN (non-focused speakers shown as passive)")
    print()

    choice = input("Select (1-3): ").strip()

    try:
        if choice == "1":
            await example_extract_speaker_id()
        elif choice == "2":
            await example_speaker_focus_ignore()
        elif choice == "3":
            await example_speaker_focus_retain()
        else:
            print("Invalid choice")
    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
