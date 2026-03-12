"""
Demo functions for the Voice API Explorer.

Each demo showcases a different aspect of the Speechmatics Voice/RT API.
"""

import asyncio
import json

from core import (
    run_session,
    print_msg,
    header,
    subheader,
    audio_format_block,
)


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 1: RT Mode — Basic Transcription
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_rt_basic(api_key, server, pcm, sr):
    """RT mode: stream audio via /v2, receive partials and finals."""
    header("Demo 1: RT Mode — Real-Time Transcription")
    print("  Mode:     RT (no profile)")
    print("  Endpoint: /v2")
    print("  Shows:    AddPartialTranscript, AddTranscript, confidence scores,")
    print("            punctuation, EndOfUtterance, RecognitionStarted")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_partials": True,
            "operating_point": "enhanced",
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 2: RT Mode — Translation
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_rt_translate(api_key, server, pcm, sr):
    """RT mode with real-time translation to Spanish and French."""
    header("Demo 2: RT Mode — Real-Time Translation")
    print("  Mode:     RT (no profile)")
    print("  Endpoint: /v2")
    print("  Shows:    translation_config, AddPartialTranslation, AddTranslation")
    print("  Note:     Translation is RT-mode only. Not supported in Voice mode.")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_partials": True,
        },
        "translation_config": {
            "target_languages": ["ru", "fr"],
            "enable_partials": True,
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 3: Voice Mode — Single Profile (adaptive)
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_single(api_key, server, pcm, sr):
    """Voice mode with the adaptive profile — the most versatile option."""
    header("Demo 3: Voice Mode — Adaptive Profile")
    print("  Mode:     Voice")
    print("  Endpoint: /v2/agent/adaptive")
    print("  Shows:    AddPartialSegment, AddSegment, SpeakerStarted/Ended,")
    print("            StartOfTurn, EndOfTurn, SessionMetrics, SpeakerMetrics")
    print()

    config = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 4: Voice Mode — Profile Comparison
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_profiles(api_key, server, pcm, sr):
    """Compare all four voice profiles with the same audio."""
    header("Demo 4: Voice Mode — Profile Comparison")
    print("  Runs the same audio through all four profiles to compare behaviour.")
    print("  Profiles are selected via URL path: /v2/agent/{profile}")
    print("  Versioning is also supported, e.g. /v2/agent/adaptive:latest")
    print()

    profiles = [
        ("agile", "Fastest response, VAD-based turn detection"),
        ("adaptive", "Adapts to speaker pace and disfluency"),
        ("smart", "Acoustic model for turn completion"),
        ("external", "Client-controlled turn detection"),
    ]

    for profile, desc in profiles:
        subheader(f"Profile: {profile} — {desc}")
        print(f"  Endpoint: /v2/agent/{profile}")
        print()

        config = {
            "transcription_config": {
                "language": "en",
            },
            "audio_format": audio_format_block(sr),
        }

        # For external profile, manually trigger end-of-utterance
        after_fn = None
        if profile == "external":

            async def force_eou(ws):
                await asyncio.sleep(0.5)
                print("    >> Sending ForceEndOfUtterance")
                await ws.send(json.dumps({"message": "ForceEndOfUtterance"}))

            after_fn = force_eou

        try:
            await run_session(
                api_key=api_key,
                server=server,
                path=f"/v2/agent/{profile}",
                config=config,
                pcm=pcm,
                sample_rate=sr,
                on_message=print_msg,
                after_audio_fn=after_fn,
            )
        except Exception as e:
            print(f"    [Error] {type(e).__name__}: {e}")

        print()


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 5: Voice Mode — Advanced Features
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_voice_advanced(api_key, server, pcm, sr):
    """Speaker focus, ForceEndOfUtterance, GetSpeakers, and diarization."""
    header("Demo 5: Voice Mode — Advanced Features")
    print("  Features: enable_diarization, UpdateSpeakerFocus, GetSpeakers,")
    print("            ForceEndOfUtterance, SpeakersResult, focus_mode")
    print()

    config = {
        "transcription_config": {
            "language": "en",
            "enable_diarization": True,
        },
        "audio_format": audio_format_block(sr),
    }

    async def mid_session_actions(ws):
        """Demonstrate mid-session control messages."""
        # 1. Request speaker identification data
        print()
        print("    >> Sending GetSpeakers")
        await ws.send(json.dumps({"message": "GetSpeakers"}))
        await asyncio.sleep(1.0)

        # 2. Update speaker focus — retain mode (non-focused speakers are passive)
        print("    >> Sending UpdateSpeakerFocus (focus S1, mode=retain)")
        await ws.send(
            json.dumps(
                {
                    "message": "UpdateSpeakerFocus",
                    "speaker_focus": {
                        "focus_speakers": ["S1"],
                        "ignore_speakers": [],
                        "focus_mode": "retain",
                    },
                }
            )
        )
        await asyncio.sleep(0.5)

        # 3. Force end of utterance
        print("    >> Sending ForceEndOfUtterance")
        await ws.send(json.dumps({"message": "ForceEndOfUtterance"}))
        await asyncio.sleep(0.5)

        # 4. Switch to ignore mode (non-focused speakers are dropped entirely)
        print("    >> Sending UpdateSpeakerFocus (focus S1, mode=ignore)")
        await ws.send(
            json.dumps(
                {
                    "message": "UpdateSpeakerFocus",
                    "speaker_focus": {
                        "focus_speakers": ["S1"],
                        "ignore_speakers": [],
                        "focus_mode": "ignore",
                    },
                }
            )
        )
        await asyncio.sleep(0.3)

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
        after_audio_fn=mid_session_actions,
    )


# ═══════════════════════════════════════════════════════════════════════════════
# DEMO 6: Message Control — Include/Exclude
# ═══════════════════════════════════════════════════════════════════════════════


async def demo_message_control(api_key, server, pcm, sr):
    """Demonstrate message_control to opt in/out of optional message types."""
    header("Demo 6: Message Control — Include/Exclude")

    # ── Part A: Include optional messages ──
    subheader("Part A: Include optional messages")
    print("  AudioAdded, SpeechStarted, SpeechEnded are NOT forwarded by default.")
    print("  Using message_control.include to opt in.")
    print()

    config_include = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
        "message_control": {
            "include": ["AudioAdded", "SpeechStarted", "SpeechEnded"],
        },
    }

    # show_optional=True so AudioAdded/SpeechStarted/SpeechEnded are printed
    def print_with_optional(msg):
        print_msg(msg, show_optional=True)

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/adaptive",
        config=config_include,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_with_optional,
    )

    # ── Part B: Exclude default messages ──
    subheader("Part B: Exclude default messages")
    print("  SpeakerMetrics and SessionMetrics are forwarded by default in Voice mode.")
    print("  Using message_control.exclude to opt out.")
    print()

    config_exclude = {
        "transcription_config": {
            "language": "en",
        },
        "audio_format": audio_format_block(sr),
        "message_control": {
            "exclude": ["SpeakerMetrics", "SessionMetrics"],
        },
    }

    await run_session(
        api_key=api_key,
        server=server,
        path="/v2/agent/agile",
        config=config_exclude,
        pcm=pcm,
        sample_rate=sr,
        on_message=print_msg,
    )
