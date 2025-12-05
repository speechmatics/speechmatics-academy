#!/usr/bin/env python3
"""
Simple Voice Bot - Web Client Version

A conversational voice bot with browser-based audio using:
- Speechmatics STT (Speech-to-Text) with diarization
- OpenAI LLM (Language Model)
- ElevenLabs TTS (Text-to-Speech)
- FastAPI + WebRTC (Browser audio)

Run with: python main.py
Then open: http://localhost:7860/client
"""

import os
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from loguru import logger

logger.info("Loading Silero VAD model...")
from pipecat.audio.vad.silero import SileroVADAnalyzer

logger.info("Loading pipeline components...")
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import LLMRunFrame
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import LLMContextAggregatorPair
from pipecat.runner.types import RunnerArguments
from pipecat.runner.utils import create_transport
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transports.base_transport import BaseTransport, TransportParams

logger.info("All components loaded!")

load_dotenv(override=True)


def load_agent_prompt() -> str:
    """Load the agent system prompt from agent.md file."""
    agent_file = Path(__file__).parent.parent / "assets" / "agent.md"
    if agent_file.exists():
        return agent_file.read_text()
    return "You are a helpful voice assistant. Be concise and friendly."


async def run_bot(transport: BaseTransport, runner_args: RunnerArguments):
    """
    Run the voice bot pipeline.

    Pipeline flow:
    1. WebRTC Audio -> Audio input from browser
    2. Speechmatics STT -> Transcribes speech to text (with diarization)
    3. User Aggregator -> Builds user message for LLM
    4. OpenAI LLM -> Generates response
    5. ElevenLabs TTS -> Converts response to speech
    6. WebRTC Audio -> Audio output to browser
    7. Assistant Aggregator -> Tracks assistant responses
    """
    logger.info("Starting bot")

    agent_prompt = load_agent_prompt()

    # Speech-to-Text: Speechmatics with diarization
    stt = SpeechmaticsSTTService(
        api_key=os.getenv("SPEECHMATICS_API_KEY"),
        enable_diarization=True,
        focus_speakers=["S1"],
        end_of_utterance_silence_trigger=0.5,
        speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
        speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
    )

    # Text-to-Speech: ElevenLabs
    tts = ElevenLabsTTSService(
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

    context = LLMContext(messages)
    context_aggregator = LLMContextAggregatorPair(context)

    # Build Pipeline
    pipeline = Pipeline(
        [
            transport.input(),
            stt,
            context_aggregator.user(),
            llm,
            tts,
            transport.output(),
            context_aggregator.assistant(),
        ]
    )

    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            enable_metrics=True,
        ),
    )

    @transport.event_handler("on_client_connected")
    async def on_client_connected(transport, client):
        logger.info("Client connected")
        # Kick off the conversation
        messages.append({"role": "system", "content": "Say hello and briefly introduce yourself."})
        await task.queue_frames([LLMRunFrame()])

    @transport.event_handler("on_client_disconnected")
    async def on_client_disconnected(transport, client):
        logger.info("Client disconnected")
        await task.cancel()

    runner = PipelineRunner(handle_sigint=runner_args.handle_sigint)
    await runner.run(task)


async def bot(runner_args: RunnerArguments):
    """Main bot entry point."""
    transport_params = {
        "webrtc": lambda: TransportParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            vad_analyzer=SileroVADAnalyzer(params=VADParams(min_volume=0.6)),
        ),
    }

    transport = await create_transport(runner_args, transport_params)
    await run_bot(transport, runner_args)


if __name__ == "__main__":
    from pipecat.runner.run import main

    main()
