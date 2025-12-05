#
# Copyright (c) 2024–2025, Daily
#
# SPDX-License-Identifier: BSD 2-Clause License
#

import argparse
import os
from datetime import datetime

from loguru import logger
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_response import (
    LLMUserAggregatorParams,
)
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat.services.azure.llm import AzureLLMService
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.speechmatics.stt import SpeechmaticsSTTService
from pipecat.transcriptions.language import Language
from pipecat.transports.base_transport import BaseTransport, TransportParams
from pipecat.transports.services.daily import DailyParams

from common.lib.utils import load_env, load_file

load_env(__file__)


AGENT_CONTEXT = load_file("agent.md", __file__)


transport_params = {
    "daily": lambda: DailyParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
    ),
    "webrtc": lambda: TransportParams(
        audio_in_enabled=True,
        audio_out_enabled=True,
    ),
}


class ParticipantTracker:
    def __init__(self):
        self.participant_count = 0
        self.participants = set()


async def run_example(transport: BaseTransport, _: argparse.Namespace, handle_sigint: bool):
    """Run example using Speechmatics STT."""
    logger.info("Starting bot")

    participant_tracker = ParticipantTracker()

    stt = SpeechmaticsSTTService(
        api_key=os.getenv("SPEECHMATICS_API_KEY"),
        params=SpeechmaticsSTTService.InputParams(
            language=Language.EN,
            output_locale=Language.EN_GB,
            enable_vad=True,
            enable_diarization=True,
            end_of_utterance_silence_trigger=0.5,
            speaker_active_format="<{speaker_id}>{text}</{speaker_id}>",
            speaker_passive_format="<PASSIVE><{speaker_id}>{text}</{speaker_id}></PASSIVE>",
            focus_speakers=["S1"],
        ),
    )

    tts = ElevenLabsTTSService(
        api_key=os.getenv("ELEVENLABS_API_KEY"),
        voice_id="97U3B7htAA7UsCIDST8b",
        model="eleven_turbo_v2_5",
    )

    llm = AzureLLMService(
        api_key=os.getenv("AZURE_CHATGPT_API_KEY"),
        endpoint=os.getenv("AZURE_CHATGPT_ENDPOINT"),
        model=os.getenv("AZURE_CHATGPT_MODEL"),
    )

    messages = [
        {
            "role": "system",
            "content": AGENT_CONTEXT.format(
                time=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            ),
        },
    ]

    context = OpenAILLMContext(messages)
    context_aggregator = llm.create_context_aggregator(
        context,
        user_params=LLMUserAggregatorParams(aggregation_timeout=0.005),
    )

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
            enable_usage_metrics=True,
        ),
    )

    @transport.event_handler("on_client_connected")
    async def on_client_connected(transport, client):
        logger.info("Client connected")
        participant_tracker.participant_count += 1
        if participant_tracker.participant_count == 1:
            messages.append({"role": "system", "content": "Say a short hello to the user."})
            await task.queue_frames([context_aggregator.user().get_context_frame()])

    @transport.event_handler("on_client_disconnected")
    async def on_client_disconnected(transport, client):
        logger.info("Client disconnected")
        participant_tracker.participant_count -= 1
        if participant_tracker.participant_count == 0:
            await task.cancel()

    runner = PipelineRunner(handle_sigint=handle_sigint)

    await runner.run(task)


if __name__ == "__main__":
    from pipecat.examples.run import main

    main(run_example, transport_params=transport_params)
