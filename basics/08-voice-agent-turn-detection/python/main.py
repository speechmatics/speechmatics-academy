#!/usr/bin/env python3
"""
Voice Agent Turn Detection - Preset Configurations

Demonstrates the official Speechmatics Voice SDK presets for turn detection.
Each preset is optimized for specific use cases.
"""

import asyncio
import os
import sys
from dotenv import load_dotenv
from speechmatics.rt import Microphone, AuthenticationError
from speechmatics.voice import (
    VoiceAgentClient,
    VoiceAgentConfigPreset,
    AgentServerMessageType,
)


load_dotenv()


async def run_preset(preset_name: str):
    """Run a voice agent with the specified preset."""

    # Load preset configuration from SDK
    config = VoiceAgentConfigPreset.load(preset_name)

    print("=" * 70)
    print(f"PRESET: {preset_name.upper()}")
    print("=" * 70)
    print(f"Mode: {config.end_of_utterance_mode.value}")
    print(f"Operating Point: {config.operating_point.value}")
    print(f"Silence Trigger: {config.end_of_utterance_silence_trigger}s")
    print(f"Max Delay: {config.max_delay}s")
    print()
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

        while True:
            audio_chunk = await mic.read(320)
            await client.send_audio(audio_chunk)

    except KeyboardInterrupt:
        print(f"\n\nStopped. Captured {len(segments)} segments.")
    finally:
        mic.stop()
        try:
            await client.disconnect()
        except:
            pass

    return segments


def show_presets():
    """Display available presets."""
    presets = VoiceAgentConfigPreset.list_presets()

    print("\nAvailable Presets:")
    print("=" * 70)

    descriptions = {
        "low_latency": "Quick finalization, best for real-time captions",
        "conversation_adaptive": "Adapts to speech patterns, best for voice assistants",
        "conversation_smart_turn": "ML-based turn detection for conversations",
        "scribe": "Optimized for note-taking and dictation",
        "captions": "Consistent formatting for live captioning",
        "external": "Manual turn control for custom logic",
    }

    for i, preset in enumerate(presets, 1):
        desc = descriptions.get(preset, "")
        print(f"{i}. {preset:25} - {desc}")

    print("=" * 70)


async def main():
    """Main entry point."""

    # Get available presets
    available_presets = VoiceAgentConfigPreset.list_presets()

    # Show presets and get choice
    show_presets()
    print()

    try:
        choice = input("Select preset number (or press Enter for conversation_adaptive): ").strip()

        if not choice:
            preset_name = "conversation_adaptive"
        else:
            preset_idx = int(choice) - 1
            if 0 <= preset_idx < len(available_presets):
                preset_name = available_presets[preset_idx]
            else:
                print(f"Invalid choice. Using conversation_adaptive.")
                preset_name = "conversation_adaptive"

    except (ValueError, KeyboardInterrupt):
        print("\nUsing default: conversation_adaptive")
        preset_name = "conversation_adaptive"

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

    except (AuthenticationError, ValueError) as e:
        print(f"\nAuthentication Error: {e}")
        if not os.getenv("SPEECHMATICS_API_KEY"):
            print("Error: SPEECHMATICS_API_KEY not set")
            print("Please set it in your .env file")
        return


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
