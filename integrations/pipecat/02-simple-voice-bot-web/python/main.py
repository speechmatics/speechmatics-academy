#!/usr/bin/env python3
"""
Simple Voice Bot - Web Client Version

A conversational voice bot with browser-based audio using.
Bot is built for speed using Speechmatics 'EXTERNAL' mode to force finalise.

:
- Speechmatics STT (Speech-to-Text) with diarization
- Groq LLM (Language Model)
- Cartesia TTS (Text-to-Speech)

Run with: uv run main.py
Then open: http://localhost:7860/client
"""

import os
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv
from loguru import logger

print("Starting Pipecat bot...")
print("Loading models and imports (20 seconds, first run only)\n")

logger.info("Loading Local Smart Turn Analyzer V3 and Silero VAD...")
from pipecat.audio.turn.smart_turn.local_smart_turn_v3 import LocalSmartTurnAnalyzerV3
from pipecat.audio.vad.silero import SileroVADAnalyzer

from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import LLMRunFrame

from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    LLMContextAggregatorPair,
    LLMUserAggregatorParams,
)
from pipecat.runner.types import RunnerArguments
from pipecat.runner.utils import create_transport
from pipecat.services.cartesia.tts import CartesiaTTSService
from pipecat.services.groq.llm import GroqLLMService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transports.base_transport import BaseTransport, TransportParams
from pipecat.transports.daily.transport import DailyParams
from pipecat.turns.user_stop.turn_analyzer_user_turn_stop_strategy import (
TurnAnalyzerUserTurnStopStrategy,
)
from pipecat.turns.user_turn_strategies import UserTurnStrategies


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
    4. Groq LLM -> Generates response
    5. Cartesia TTS -> Converts response to speech
    6. WebRTC Audio -> Audio output to browser

    """
    logger.info("Starting bot")

    agent_prompt = load_agent_prompt()

    # Speech-to-Text: Speechmatics with diarization
    stt = SpeechmaticsSTTService(
        api_key=os.getenv("SPEECHMATICS_API_KEY"),
        params=SpeechmaticsSTTService.InputParams(
            # Turn detection mode - EXTERNAL means handled by Pipecat
            turn_detection_mode=SpeechmaticsSTTService.TurnDetectionMode.EXTERNAL,
            # Diarization settings
            enable_speaker_diarization=True,
            focus_speakers=["S1"],
            speaker_active_format="<{speaker_id}>{text}</{speaker_id}>", 
            speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
        ),
    )

    # Text-to-Speech: Cartesia
    tts = CartesiaTTSService(
        api_key=os.getenv("CARTESIA_API_KEY"),
        voice_id="71a7ad14-091c-4e8e-a314-022ece01c121",
        model="sonic-3",
    )

    # Language Model: Groq
    llm = GroqLLMService(
        api_key=os.getenv("GROQ_API_KEY"),
        model="openai/gpt-oss-120b",
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

    # context aggregator
    context = LLMContext(messages)
    user_aggregator, assistant_aggregator = LLMContextAggregatorPair(
        context,
        user_params=LLMUserAggregatorParams(
            user_turn_strategies=UserTurnStrategies(
                stop=[
                    TurnAnalyzerUserTurnStopStrategy(
                        turn_analyzer=LocalSmartTurnAnalyzerV3()
                    )
                ]
            ),
        ),
    )

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
            enable_metrics=True,
            enable_usage_metrics=True,
        ),
    )

    @transport.event_handler("on_client_connected")
    async def on_client_connected(transport, client):
        logger.info("Client connected")
        messages.append(
            {"role": "system", "content": "Say hello and briefly introduce yourself."}
        )
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
        "daily": lambda: DailyParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
            # turn_analyzer=LocalSmartTurnAnalyzerV3(), # optional: more robust turn detection

        ),
        "webrtc": lambda: TransportParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            vad_analyzer=SileroVADAnalyzer(params=VADParams(stop_secs=0.2)),
            # turn_analyzer=LocalSmartTurnAnalyzerV3(), # optional: more robust turn detection

        ),
    }

    transport = await create_transport(runner_args, transport_params)
    await run_bot(transport, runner_args)


if __name__ == "__main__":
    from pipecat.runner.run import main

    main()