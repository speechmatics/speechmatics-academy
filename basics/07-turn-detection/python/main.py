#!/usr/bin/env python3
"""
Turn Detection - Detect When Speech Ends

Demonstrate real-time turn detection to identify when a speaker has finished speaking.
"""

import asyncio
import os
from dotenv import load_dotenv
from speechmatics.rt import (
    AsyncClient,
    AudioEncoding,
    AudioFormat,
    Microphone,
    TranscriptionConfig,
    ConversationConfig,
    TranscriptResult,
    ServerMessageType,
    AuthenticationError,
)

load_dotenv()


async def main() -> None:
    # Check API key first for immediate feedback
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    if not api_key:
        print("Error: SPEECHMATICS_API_KEY not set")
        print("Please set it in your .env file")
        return

    utterances = []
    current_utterance = []
    utterance_start_time = None

    audio_format = AudioFormat(
        encoding=AudioEncoding.PCM_S16LE,
        chunk_size=4096,
        sample_rate=16000,
    )

    transcription_config = TranscriptionConfig(
        language="en",
        enable_partials=True,
        conversation_config=ConversationConfig(
            end_of_utterance_silence_trigger=0.7
        ),
    )

    mic = Microphone(
        sample_rate=audio_format.sample_rate,
        chunk_size=audio_format.chunk_size,
    )

    if not mic.start():
        print("PyAudio not installed - microphone not available")
        print("Install with: pip install pyaudio")
        return

    print("=" * 70)
    print("TURN DETECTION")
    print("=" * 70)
    print()
    print("Speak and pause to trigger turn detection...")
    print("Press Ctrl+C to stop")
    print()

    try:
        async with AsyncClient(api_key=api_key) as client:

            @client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
            def handle_partial(message):
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    print(f"\r> {transcript}", end="", flush=True)

            @client.on(ServerMessageType.ADD_TRANSCRIPT)
            def handle_transcript(message):
                nonlocal utterance_start_time
                result = TranscriptResult.from_message(message)
                transcript = result.metadata.transcript
                if transcript:
                    # Track start time of first segment in utterance
                    if not current_utterance:
                        utterance_start_time = result.metadata.start_time
                    current_utterance.append(transcript.strip())

            @client.on(ServerMessageType.END_OF_UTTERANCE)
            def handle_end_of_utterance(message):
                nonlocal utterance_start_time
                print("\r" + " " * 80, end="\r")

                if current_utterance and utterance_start_time is not None:
                    full_text = " ".join(current_utterance)

                    # END_OF_UTTERANCE has end_of_utterance_time directly in message
                    end_time = message.get("end_of_utterance_time", 0)
                    duration = end_time - utterance_start_time

                    utterances.append({
                        "text": full_text,
                        "duration": duration
                    })

                    print(f"Turn {len(utterances)}: {full_text} ({duration:.2f}s)")
                    print()
                    current_utterance.clear()
                    utterance_start_time = None

            await client.start_session(
                transcription_config=transcription_config,
                audio_format=audio_format,
            )

            while True:
                frame = await mic.read(audio_format.chunk_size)
                await client.send_audio(frame)

    except AuthenticationError as e:
        print(f"\nAuthentication failed: {e}")
    except asyncio.CancelledError:
        print("\n")
        print("Session ended")
    except Exception as e:
        print(f"\nError: {e}")
    finally:
        mic.stop()

    if utterances:
        print()
        print("=" * 70)
        print(f"DETECTED {len(utterances)} TURNS")
        print("=" * 70)
        for i, utterance in enumerate(utterances, 1):
            print(f"{i}. {utterance['text']} ({utterance['duration']:.2f}s)")
    else:
        print("\nNo turns detected")


if __name__ == "__main__":
    asyncio.run(main())
