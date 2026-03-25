"""Capture all unique message types from the server across all profiles."""

import asyncio
import json
import os
from collections import defaultdict
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

from core import audio_format_block, read_wav, run_session  # noqa: E402

API_KEY = os.environ.get("SPEECHMATICS_API_KEY")
SERVER = os.environ.get("SM_SERVER", "wss://preview.rt.speechmatics.com")

if not API_KEY:
    print("Error: SPEECHMATICS_API_KEY not set")
    exit(1)

seen = defaultdict(list)  # msg_type -> [profile, ...]


def make_tracker(profile):
    """Return an on_message callback that logs unique message types."""

    def on_message(msg, **kwargs):
        mt = msg.get("message", "???")
        if mt not in [p for p in seen if profile in seen[p]]:
            seen[mt].append(profile)
        # Print anything with "turn" or "smart" or "prediction" in the name
        mt_lower = mt.lower()
        if any(k in mt_lower for k in ["turn", "smart", "prediction"]):
            print(f"    [{mt}] {json.dumps(msg)[:200]}")

    return on_message


async def main():
    wav_path = Path(__file__).parent / "sample.wav"
    if not wav_path.exists():
        print("No sample.wav found.")
        return

    pcm, sr = read_wav(wav_path)

    config = {
        "transcription_config": {"language": "en"},
        "audio_format": audio_format_block(sr),
    }

    profiles = [
        ("/v2", "RT"),
        ("/v2/agent/agile", "agile"),
        ("/v2/agent/adaptive", "adaptive"),
        ("/v2/agent/smart", "smart"),
        ("/v2/agent/external", "external"),
    ]

    for path, name in profiles:
        print(f"\n{'=' * 60}")
        print(f"  Profile: {name} ({path})")
        print(f"{'=' * 60}")

        after_fn = None
        if name == "external":

            async def force_eou(ws):
                await asyncio.sleep(0.5)
                await ws.send(json.dumps({"message": "ForceEndOfUtterance"}))

            after_fn = force_eou

        try:
            await run_session(
                api_key=API_KEY,
                server=SERVER,
                path=path,
                config=config,
                pcm=pcm,
                sample_rate=sr,
                on_message=make_tracker(name),
                after_audio_fn=after_fn,
            )
        except Exception as e:
            print(f"  [Error] {type(e).__name__}: {e}")

    print(f"\n{'=' * 60}")
    print("  SUMMARY: All unique message types observed")
    print(f"{'=' * 60}")
    for mt in sorted(seen.keys()):
        profiles_list = ", ".join(seen[mt])
        marker = " <<<" if "turn" in mt.lower() or "smart" in mt.lower() or "prediction" in mt.lower() else ""
        print(f"  {mt:30s} [{profiles_list}]{marker}")


if __name__ == "__main__":
    asyncio.run(main())
