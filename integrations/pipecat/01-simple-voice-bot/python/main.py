#!/usr/bin/env python3
"""
Simple Voice Bot - Pipecat + Speechmatics Integration

A conversational voice bot using:
- Speechmatics STT (Speech-to-Text)
- OpenAI LLM (Language Model)
- ElevenLabs TTS (Text-to-Speech)
- Local Audio (Microphone + Speakers)

"""

import asyncio
import os
from datetime import datetime
from pathlib import Path

import aiohttp
from dotenv import load_dotenv
from loguru import logger
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    LLMAssistantAggregator,
    LLMUserAggregator,
)
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transports.local.audio import LocalAudioTransport, LocalAudioTransportParams

load_dotenv()


def load_agent_prompt() -> str:
    """Load the agent system prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a helpful voice assistant. Be concise and friendly."


async def main():
    """
    Run the voice bot pipeline.

    Pipeline flow:
    1. Local Microphone -> Audio input from user
    2. Silero VAD -> Detects speech start/stop; signals end-of-turn to STT
    3. Speechmatics STT -> Transcribes speech to text
    4. User Aggregator -> Builds user message for LLM
    5. OpenAI LLM -> Generates response
    6. ElevenLabs TTS -> Converts response to speech
    7. Local Speakers -> Audio output to user
    8. Assistant Aggregator -> Tracks assistant responses
    """
    # Check required API keys first for immediate feedback
    missing_keys = []
    if not os.getenv("SPEECHMATICS_API_KEY"):
        missing_keys.append("SPEECHMATICS_API_KEY")
    if not os.getenv("OPENAI_API_KEY"):
        missing_keys.append("OPENAI_API_KEY")
    if not os.getenv("ELEVENLABS_API_KEY"):
        missing_keys.append("ELEVENLABS_API_KEY")

    if missing_keys:
        logger.error(f"Missing required API keys: {', '.join(missing_keys)}")
        logger.error("Please set them in your .env file")
        return

    logger.info("Starting voice bot...")
    logger.info("Speak first to register as the primary speaker (S1).")
    logger.info("Press Ctrl+C to exit.")

    agent_prompt = load_agent_prompt()

    async with aiohttp.ClientSession() as session:
        # Local Audio Transport (Microphone + Speakers).
        # NOTE: in pipecat 1.x, transport params no longer accept vad_analyzer;
        # VAD is now a separate FrameProcessor inserted into the pipeline below.
        transport = LocalAudioTransport(
            LocalAudioTransportParams(
                audio_in_enabled=True,
                audio_out_enabled=True,
            )
        )

        # Voice Activity Detection: Silero VAD as a pipeline processor. When
        # speech stops, this broadcasts VADUserStoppedSpeakingFrame, which the
        # Speechmatics STT service uses to drive end-of-utterance in EXTERNAL
        # turn-detection mode (the service's default).
        vad_processor = VADProcessor(vad_analyzer=SileroVADAnalyzer())

        # Speech-to-Text: Speechmatics. Defaults turn_detection_mode to EXTERNAL,
        # so user turns close when the pipeline emits VADUserStoppedSpeakingFrame
        # from the VAD processor above (rather than a server-side silence timer).
        stt = SpeechmaticsSTTService(
            api_key=os.getenv("SPEECHMATICS_API_KEY"),
            settings=SpeechmaticsSTTService.Settings(
                enable_diarization=True,
                focus_speakers=["S1"],
                speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
                speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
            ),
        )

        # Text-to-Speech: ElevenLabs
        tts = ElevenLabsTTSService(
            aiohttp_session=session,
            api_key=os.getenv("ELEVENLABS_API_KEY"),
            settings=ElevenLabsTTSService.Settings(voice="21m00Tcm4TlvDq8ikWAM"),  # Rachel
        )

        # Language Model: OpenAI
        llm = OpenAILLMService(
            api_key=os.getenv("OPENAI_API_KEY"),
            settings=OpenAILLMService.Settings(model="gpt-4o-mini"),
        )

        # Conversation Context
        messages = [
            {
                "role": "system",
                "content": agent_prompt.format(
                    time=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                ),
            },
        ]

        context = LLMContext(messages)
        user_aggregator = LLMUserAggregator(context)
        assistant_aggregator = LLMAssistantAggregator(context)

        # Build Pipeline. The VAD processor sits between mic input and STT so
        # it can detect speech stop and emit VADUserStoppedSpeakingFrame, which
        # drives end-of-utterance for the Speechmatics STT service.
        pipeline = Pipeline(
            [
                transport.input(),
                vad_processor,
                stt,
                user_aggregator,
                llm,
                tts,
                transport.output(),
                assistant_aggregator,
            ]
        )

        task = PipelineTask(
            pipeline,
            params=PipelineParams(
                allow_interruptions=True,
                enable_metrics=True,
            ),
        )

        runner = PipelineRunner()
        await runner.run(task)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Voice bot stopped.")
