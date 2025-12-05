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

from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_response import (
    LLMAssistantContextAggregator,
    LLMUserContextAggregator,
)
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transports.local.audio import LocalAudioTransport, LocalAudioTransportParams
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams

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
    2. Speechmatics STT -> Transcribes speech to text
    3. User Aggregator -> Builds user message for LLM
    4. OpenAI LLM -> Generates response
    5. ElevenLabs TTS -> Converts response to speech
    6. Local Speakers -> Audio output to user
    7. Assistant Aggregator -> Tracks assistant responses
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
        # Local Audio Transport (Microphone + Speakers)
        transport = LocalAudioTransport(
            LocalAudioTransportParams(
                audio_in_enabled=True,
                audio_out_enabled=True,
                vad_analyzer=SileroVADAnalyzer(
                    params=VADParams(min_volume=0.6)
                ),
            )
        )

        # Speech-to-Text: Speechmatics
        stt = SpeechmaticsSTTService(
            api_key=os.getenv("SPEECHMATICS_API_KEY"),
            params=SpeechmaticsSTTService.InputParams(
                enable_diarization=True,
                focus_speakers=["S1"],
                end_of_utterance_silence_trigger=0.5,
                speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
                speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
            ),
        )

        # Text-to-Speech: ElevenLabs
        tts = ElevenLabsTTSService(
            aiohttp_session=session,
            api_key=os.getenv("ELEVENLABS_API_KEY"),
            voice_id="21m00Tcm4TlvDq8ikWAM",  # Rachel
        )

        # Language Model: OpenAI
        llm = OpenAILLMService(
            api_key=os.getenv("OPENAI_API_KEY"),
            model="gpt-4o-mini",
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

        context = OpenAILLMContext(messages)
        user_aggregator = LLMUserContextAggregator(context)
        assistant_aggregator = LLMAssistantContextAggregator(context)

        # Build Pipeline
        pipeline = Pipeline(
            [
                transport.input(),
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
