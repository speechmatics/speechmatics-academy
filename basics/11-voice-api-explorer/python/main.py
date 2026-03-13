"""
Voice API Explorer — CLI Entry Point

Comprehensive demo of the Speechmatics Voice API — a unified WebSocket
endpoint for both real-time transcription (RT) and voice agent (Voice) modes.

Default input is your microphone — speak, press Enter to stop, then demos
replay your recording through each API mode and profile.

Usage:
    python main.py                     # Interactive menu (mic input)
    python main.py rt                  # RT mode transcription
    python main.py voice               # Voice mode (adaptive profile)
    python main.py profiles            # Compare all voice profiles
    python main.py advanced            # Speaker focus, ForceEOU, GetSpeakers
    python main.py messages            # Message control include/exclude
    python main.py all                 # Run all demos
    python main.py rt --audio f.wav    # Use a WAV file instead of mic
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

import core
from core import DEFAULT_SERVER, read_wav, record_audio
from demos import (
    demo_message_control,
    demo_rt_basic,
    demo_voice_advanced,
    demo_voice_profiles,
    demo_voice_single,
)

# ═══════════════════════════════════════════════════════════════════════════════
# CLI & Main
# ═══════════════════════════════════════════════════════════════════════════════

DEMOS = {
    "rt": ("RT Mode — Transcription", demo_rt_basic),
    "voice": ("Voice Mode — Adaptive Profile", demo_voice_single),
    "profiles": ("Voice Mode — Profile Comparison", demo_voice_profiles),
    "advanced": ("Voice Mode — Advanced Features", demo_voice_advanced),
    "messages": ("Message Control — Include/Exclude", demo_message_control),
}


def show_menu():
    """Display interactive demo selection menu."""
    print()
    print("=" * 60)
    print("  Speechmatics Voice API Explorer")
    print("=" * 60)
    print()
    print("  Select a demo to run:")
    print()
    for i, (key, (title, _)) in enumerate(DEMOS.items(), 1):
        print(f"    {i}. [{key}] {title}")
    print(f"    {len(DEMOS) + 1}. [all] Run all demos")
    print("    0. Exit")
    print()

    while True:
        try:
            choice = input("  Enter number or name: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return None

        if choice == "0" or choice == "exit":
            return None
        if choice == "all" or choice == str(len(DEMOS) + 1):
            return "all"

        # Match by number
        if choice.isdigit():
            idx = int(choice) - 1
            keys = list(DEMOS.keys())
            if 0 <= idx < len(keys):
                return keys[idx]

        # Match by name
        if choice in DEMOS:
            return choice

        print("  Invalid choice. Try again.")


async def run(demo_keys: list, api_key: str, server: str, pcm: bytes, sr: int):
    """Run the selected demos."""
    for key in demo_keys:
        _, func = DEMOS[key]
        await func(api_key, server, pcm, sr)


def main():
    parser = argparse.ArgumentParser(
        description="Speechmatics Voice API Explorer — demo all features",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Available demos:
  rt            RT mode basic transcription (partials, finals, confidence)
  voice         Voice mode with adaptive profile (segments, turns, metrics)
  profiles      Compare all voice profiles (agile, adaptive, smart, external)
  advanced      Speaker focus, ForceEOU, GetSpeakers, diarization
  messages      Message control include/exclude
  all           Run all demos in sequence

Audio input:
  Default is live microphone — speak, press Enter to stop.
  Use --audio to provide a WAV file instead.
        """,
    )
    parser.add_argument(
        "demo",
        nargs="?",
        default=None,
        help="Demo to run (see list above). Omit for interactive menu.",
    )
    parser.add_argument(
        "--server",
        default=os.getenv("SPEECHMATICS_SERVER", DEFAULT_SERVER),
        help=f"WebSocket server URL (default: {DEFAULT_SERVER})",
    )
    parser.add_argument(
        "--audio",
        default=None,
        help="Path to a 16-bit mono WAV file. If omitted, records from microphone.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show raw WebSocket URL, StartRecognition payload, and all received messages.",
    )
    args = parser.parse_args()

    core.DEBUG = args.debug

    # ── Validate API key ──
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file or environment")
        sys.exit(1)

    # ── Select demo first (before recording) ──
    if args.demo:
        demo_key = args.demo.lower()
    else:
        demo_key = show_menu()

    if demo_key is None:
        print("Exiting.")
        return

    if demo_key == "all":
        keys = list(DEMOS.keys())
    elif demo_key in DEMOS:
        keys = [demo_key]
    else:
        print(f"Unknown demo: {demo_key}")
        print(f"Available: {', '.join(DEMOS.keys())}, all")
        sys.exit(1)

    # ── Get audio ──
    if args.audio:
        # File mode
        audio_path = Path(args.audio)
        if not audio_path.exists():
            print(f"Error: Audio file not found: {audio_path}")
            sys.exit(1)
        try:
            pcm, sr = read_wav(audio_path)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        # Microphone mode (default)
        print()
        print("=" * 60)
        print("  Microphone Input")
        print("=" * 60)
        print()
        print("  Your recording will be replayed through each demo.")
        print("  Tip: speak a few sentences for best results.")
        print()
        pcm, sr = record_audio()

        if len(pcm) < sr * 2:  # Less than 1 second
            print("  Error: Recording too short. Please try again.")
            sys.exit(1)

    # ── Run ──
    print()
    print(f"  Server: {args.server}")
    asyncio.run(run(keys, api_key, args.server, pcm, sr))

    print()
    print("=" * 60)
    print("  All demos complete.")
    print("=" * 60)


if __name__ == "__main__":
    main()
