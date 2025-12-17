#!/usr/bin/env python3
"""
Voice Agent Turn Detection - Preset Configurations

"""

import asyncio
import os
import sys

import keyboard
from dotenv import load_dotenv
from speechmatics.rt import Microphone, AuthenticationError
from speechmatics.voice import (
    VoiceAgentClient,
    VoiceAgentConfigPreset,
    VoiceAgentConfig,
    AgentServerMessageType,
    EndOfUtteranceMode,
)


load_dotenv()


async def check_for_enter_key(client: VoiceAgentClient, preset_name: str):
    """
    Background task to check for Enter key press.
    When Enter is pressed, trigger end-of-utterance via the SDK.

    """
    while True:
        await asyncio.sleep(0.05)

        if preset_name != "external":
            continue

        # Check if Enter key is pressed (cross-platform)
        if keyboard.is_pressed("enter"):
            print("\n[ENTER KEY DETECTED - Triggering End of Utterance]")
            try:
                # Send ForceEndOfUtterance to server - server will respond
                # with final transcript and END_OF_UTTERANCE event
                await client.force_end_of_utterance()
            except Exception as e:
                print(f"Error triggering EOD: {e}")
            # Small delay to prevent multiple triggers from single key press
            await asyncio.sleep(0.3)


async def run_preset(preset_name: str):
    """Run a voice agent with the specified preset."""

    # Load preset configuration from SDK
    if preset_name == "external":
        # For external/manual control, use FIXED mode with max silence trigger (2s)
        # This minimizes auto-triggering while allowing force_end_of_utterance()
        # to work correctly (SDK only handles END_OF_UTTERANCE events in FIXED mode)
        # Note: Server allows 0-2 seconds for silence trigger
        config = VoiceAgentConfigPreset.load(
            "external",
            overlay_json=VoiceAgentConfig(
                end_of_utterance_mode=EndOfUtteranceMode.FIXED,
                end_of_utterance_silence_trigger=2.0,
            ).model_dump_json(exclude_unset=True)
        )
    else:
        config = VoiceAgentConfigPreset.load(preset_name)

    print("=" * 70)
    print(f"PRESET: {preset_name.upper()}")
    print("=" * 70)
    print(f"Mode: {config.end_of_utterance_mode.value}")
    print(f"Operating Point: {config.operating_point.value}")
    print(f"Silence Trigger: {config.end_of_utterance_silence_trigger}s")
    print(f"Max Delay: {config.max_delay}s")
    print()

    if preset_name == "external":
        print("Press ENTER to trigger end-of-utterance manually.")
        print("Press Ctrl+C to stop.")
    else:
        print("Speak into your microphone. Press Ctrl+C to stop.")

    print("=" * 70)
    print()

    segments = []

    # Create client with preset
    client = VoiceAgentClient(
        api_key=os.getenv("SPEECHMATICS_API_KEY"),
        config=config
    )

    # Event handlers
    @client.on(AgentServerMessageType.ADD_PARTIAL_SEGMENT)
    def on_partial(message):
        for segment in message.get("segments", []):
            print(f"\r> {segment['text']}", end="", flush=True)

    @client.on(AgentServerMessageType.ADD_SEGMENT)
    def on_final(message):
        for segment in message.get("segments", []):
            speaker = segment.get("speaker_id", "S1")
            text = segment["text"]
            segments.append((speaker, text))
            print(f"\n[{speaker}]: {text}")

    @client.on(AgentServerMessageType.END_OF_TURN)
    def on_turn_end(message):
        print("[END OF TURN]\n")

    # Setup microphone
    mic = Microphone(sample_rate=16000, chunk_size=320)
    if not mic.start():
        print("Error: PyAudio not installed")
        print("Install with: pip install pyaudio")
        return segments

    try:
        # Connect and stream
        await client.connect()

        # Start the Enter key detection task for external preset
        enter_key_task = asyncio.create_task(
            check_for_enter_key(client, preset_name)
        )

        # Main audio streaming loop
        while True:
            audio_chunk = await mic.read(320)
            await client.send_audio(audio_chunk)

    except KeyboardInterrupt:
        print(f"\n\nStopped. Captured {len(segments)} segments.")
    finally:
        # Cancel the Enter key detection task
        if 'enter_key_task' in locals():
            enter_key_task.cancel()
            try:
                await enter_key_task
            except asyncio.CancelledError:
                pass

        mic.stop()
        try:
            await client.disconnect()
        except Exception:
            pass

    return segments


def show_presets():
    """Display available presets."""
    presets = VoiceAgentConfigPreset.list_presets()

    print("\nAvailable Presets:")
    print("=" * 70)

    descriptions = {
        "fast": "Quick finalization, best for real-time captions",
        "fixed": "Fixed silence threshold, general conversational use",
        "adaptive": "Adapts to speech patterns, best for voice assistants",
        "smart_turn": "ML-based turn detection for conversations",
        "scribe": "Optimized for note-taking and dictation",
        "captions": "Consistent formatting for live captioning",
        "external": "Manual turn control for custom logic (Press ENTER to trigger EOD)",
    }

    for i, preset in enumerate(presets, 1):
        desc = descriptions.get(preset, "")
        print(f"{i}. {preset:25} - {desc}")

    print("=" * 70)


async def main():
    """Main entry point."""

    # Check API key first for immediate feedback
    if not os.getenv("SPEECHMATICS_API_KEY"):
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    # Get available presets
    available_presets = VoiceAgentConfigPreset.list_presets()

    # Show presets and get choice
    show_presets()
    print()

    try:
        choice = input("Select preset number (or press Enter for adaptive): ").strip()

        if not choice:
            preset_name = "adaptive"
        else:
            preset_idx = int(choice) - 1
            if 0 <= preset_idx < len(available_presets):
                preset_name = available_presets[preset_idx]
            else:
                print(f"Invalid choice. Using adaptive.")
                preset_name = "adaptive"

    except (ValueError, KeyboardInterrupt):
        print("\nUsing default: adaptive")
        preset_name = "adaptive"

    print()

    # Run the preset
    try:
        segments = await run_preset(preset_name)

        # Show summary
        if segments:
            print("\n" + "=" * 70)
            print("SUMMARY")
            print("=" * 70)
            for i, (speaker, text) in enumerate(segments, 1):
                print(f"{i}. [{speaker}]: {text}")

    except AuthenticationError as e:
        print(f"\nAuthentication Error: {e}")
        print("Please check your API key is valid at portal.speechmatics.com")
        return


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
