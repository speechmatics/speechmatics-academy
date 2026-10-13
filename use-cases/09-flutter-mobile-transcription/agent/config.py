"""Server-owned configuration and the small per-session personality contract."""

from __future__ import annotations

import os
from dataclasses import dataclass, field

from pydantic import BaseModel, ConfigDict, Field

DEFAULT_INSTRUCTIONS = (
    "You are EveryVoice, a helpful conversational voice assistant. "
    "Be clear, warm, and concise. Speak naturally without markdown formatting. "
    "Apply the user's communication preferences when present."
)


@dataclass(frozen=True)
class Settings:
    livekit_url: str = ""
    livekit_api_key: str = field(default="", repr=False)
    livekit_api_secret: str = field(default="", repr=False)
    app_token: str = field(default="", repr=False)
    agent_name: str = "everyvoice-agent"
    stt_language: str = "en"
    llm_model: str = "openai/gpt-4.1-mini"
    tts_model: str = "cartesia/sonic-3"
    tts_voice: str = "9626c31c-bec5-4cca-baa8-f8ba9e84c8bc"
    instructions: str = DEFAULT_INSTRUCTIONS

    def __post_init__(self) -> None:
        if (
            not self.agent_name
            or self.agent_name != self.agent_name.strip()
            or len(self.agent_name) > 128
        ):
            raise ValueError(
                "EVERYVOICE_AGENT_NAME must be a trimmed dispatch name of 1–128 characters"
            )

    @classmethod
    def from_env(cls) -> Settings:
        defaults = cls()
        return cls(
            livekit_url=os.getenv("LIVEKIT_URL", ""),
            livekit_api_key=os.getenv("LIVEKIT_API_KEY", ""),
            livekit_api_secret=os.getenv("LIVEKIT_API_SECRET", ""),
            app_token=os.getenv("EVERYVOICE_APP_TOKEN", ""),
            agent_name=os.getenv("EVERYVOICE_AGENT_NAME", defaults.agent_name),
            stt_language=os.getenv("EVERYVOICE_STT_LANGUAGE", defaults.stt_language),
            llm_model=os.getenv("EVERYVOICE_LLM_MODEL", defaults.llm_model),
            tts_model=os.getenv("EVERYVOICE_TTS_MODEL", defaults.tts_model),
            tts_voice=os.getenv("EVERYVOICE_TTS_VOICE", defaults.tts_voice),
            instructions=os.getenv("EVERYVOICE_INSTRUCTIONS", defaults.instructions),
        )


class PersonalityMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    personality: str = Field(default="", max_length=12000)


def parse_personality(metadata: str | None) -> PersonalityMetadata:
    return PersonalityMetadata.model_validate_json(metadata) if metadata else PersonalityMetadata()
