"""
Agent

High-level API for managing Agora Conversational AI Agents.
"""

import logging
import os
from typing import Any, Dict, Optional

from agora_agent import Area, AsyncAgora
from agora_agent.agentkit import Agent as AgoraAgent
from agora_agent.agentkit.vendors import MiniMaxTTS, OpenAI, SpeechmaticsSTT

logger = logging.getLogger("uvicorn.error")

ADA_PROMPT = """You are Ada, an agentic developer advocate from Agora. You help developers understand and build with Agora's Conversational AI platform.

Agora is a real-time communications company. The product you represent is the Agora Conversational AI Engine.

This Python quickstart customizes only ASR: Speechmatics replaces the default STT, while the managed OpenAI gpt-4o-mini LLM and MiniMax speech_2_6_turbo TTS remain unchanged.

The demo uses the released `agora-agents` Python package. Speechmatics is configured with `SpeechmaticsSTT(key=..., language="en", uri="wss://global.rt.speechmatics.com/v2")`; the SDK serializes the credential as `params.key`, not the deprecated `api_key` field.

For local development, Agora and Speechmatics credentials belong in the gitignored `server/.env`, using `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, and `SPEECHMATICS_API_KEY`. Deployments should provide the same names as process environment variables and should not deploy the dotenv file. Never reveal or repeat credential values.

When asked how to run this demo, explain the current repository accurately: run `bun run setup`, add the server-side Speechmatics key to `server/.env`, run `bun run doctor:local`, and start the two-process app with `bun run dev`.

If you do not know a specific fact about Agora, say so plainly and suggest checking docs.agora.io. Keep most replies to one or two sentences unless the user explicitly asks for more detail.
"""


class Agent:
    """
    High-level wrapper for Agora Conversational AI Agent operations.

    Uses AgentSession for full lifecycle management (start/stop),
    which handles Token007 authentication automatically.
    """

    def __init__(self):
        self.app_id = os.getenv("AGORA_APP_ID")
        self.app_certificate = os.getenv("AGORA_APP_CERTIFICATE")
        self.speechmatics_api_key = os.getenv("SPEECHMATICS_API_KEY")
        self.greeting = os.getenv(
            "AGENT_GREETING",
            "Hi there! I'm Ada, your virtual assistant from Agora. How can I help?",
        )

        if not self.app_id or not self.app_certificate or not self.speechmatics_api_key:
            raise ValueError("AGORA_APP_ID, AGORA_APP_CERTIFICATE, and SPEECHMATICS_API_KEY are required")

        self.client = AsyncAgora(
            area=Area.US,
            app_id=self.app_id,
            app_certificate=self.app_certificate,
        )

        # Track active sessions by agent_id
        self._sessions: Dict[str, Any] = {}

    async def start(
        self,
        channel_name: str,
        agent_uid: int,
        user_uid: int,
        output_audio_codec: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Start agent with the same default vendor chain as the Next.js quickstart."""
        if not channel_name or not str(channel_name).strip():
            raise ValueError("channel_name is required and cannot be empty")
        if agent_uid <= 0:
            raise ValueError("agent_uid is required and cannot be empty")
        if user_uid <= 0:
            raise ValueError("user_uid is required and cannot be empty")

        # Speechmatics ASR with the quickstart's managed LLM and TTS defaults.
        llm = OpenAI(
            model="gpt-4o-mini",
            greeting_message=self.greeting,
            failure_message="Please wait a moment.",
            max_history=15,
            max_tokens=1024,
            temperature=0.7,
            top_p=0.95,
        )
        stt = SpeechmaticsSTT(
            key=self.speechmatics_api_key,
            language="en",
            uri="wss://global.rt.speechmatics.com/v2",
            additional_params={
                "additional_vocab": [
                    {
                        "content": "Speechmatics",
                        "sounds_like": ["speech matics", "speech maticks", "speech mattox"],
                    },
                ],
            },
        )
        tts = MiniMaxTTS(model="speech_2_6_turbo", voice_id="English_captivating_female1")

        parameters = {
            "audio_scenario": "chorus",  # web client → ultra-low-latency chorus profile
            "data_channel": "rtm",
            "enable_error_message": True,
            "enable_metrics": True,
        }
        if isinstance(output_audio_codec, str) and output_audio_codec.strip():
            parameters["output_audio_codec"] = output_audio_codec.strip()

        agora_agent = AgoraAgent(
            client=self.client,
            instructions=ADA_PROMPT,
            greeting=self.greeting,
            failure_message="Please wait a moment.",
            max_history=50,
            turn_detection={
                "config": {
                    "speech_threshold": 0.5,
                    "start_of_speech": {
                        "mode": "vad",
                        "vad_config": {
                            "interrupt_duration_ms": 160,
                            "prefix_padding_ms": 300,
                        },
                    },
                    "end_of_speech": {
                        "mode": "vad",
                        "vad_config": {
                            "silence_duration_ms": 480,
                        },
                    },
                },
            },
            advanced_features={"enable_rtm": True, "enable_tools": True},
            parameters=parameters,
        )

        agora_agent = agora_agent.with_stt(stt).with_llm(llm).with_tts(tts)

        session = agora_agent.create_async_session(
            channel=channel_name,
            agent_uid=str(agent_uid),
            remote_uids=[str(user_uid)],
            enable_string_uid=False,
            idle_timeout=30,
            expires_in=3600,
        )

        logger.info(
            "Starting Agora agent channel=%s agent_uid=%s user_uid=%s",
            channel_name,
            agent_uid,
            user_uid,
        )

        try:
            agent_id = await session.start()
        except Exception:
            logger.exception(
                "Failed to start Agora agent channel=%s agent_uid=%s user_uid=%s",
                channel_name,
                agent_uid,
                user_uid,
            )
            raise

        # Save session for later stop
        self._sessions[agent_id] = session

        logger.info(
            "Started Agora agent agent_id=%s channel=%s agent_uid=%s user_uid=%s",
            agent_id,
            channel_name,
            agent_uid,
            user_uid,
        )

        return {
            "agent_id": agent_id,
            "channel_name": channel_name,
            "status": "started",
        }

    async def stop(self, agent_id: str) -> None:
        """Stop a running agent. Falls back to the stateless client path."""
        if not agent_id or not str(agent_id).strip():
            raise ValueError("agent_id is required and cannot be empty")

        session = self._sessions.pop(agent_id, None)
        if session:
            try:
                await session.stop()
                logger.info("Stopped Agora agent from active session agent_id=%s", agent_id)
                return
            except Exception:
                # Fall back to the stateless SDK path if the in-memory session is stale.
                logger.warning(
                    "Failed to stop Agora agent from active session; falling back to client.stop_agent agent_id=%s",
                    agent_id,
                    exc_info=True,
                )

        logger.info("Stopping Agora agent through client.stop_agent agent_id=%s", agent_id)
        await self.client.stop_agent(agent_id)
