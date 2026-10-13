import asyncio
import json
from multiprocessing.reduction import ForkingPickler
from pathlib import Path

import pytest


def test_worker_entrypoint_can_be_serialized_for_cloud_job_processes():
    from agent import create_server
    from config import Settings

    settings = Settings(agent_name="serialization-test", instructions="Configured instructions.")
    server = create_server(settings)
    serialized = ForkingPickler.dumps(server._entrypoint_fnc)
    restored = ForkingPickler.loads(serialized)
    assert restored.keywords["settings"] == settings


@pytest.mark.parametrize(
    "name",
    ["", "   ", " everyvoice-agent ", "x" * 129],
    ids=["empty", "blank", "untrimmed", "long"],
)
def test_invalid_agent_name_cannot_enable_unintended_dispatch(name):
    from config import Settings

    with pytest.raises(ValueError):
        Settings(agent_name=name)


def test_current_cli_discovers_the_named_agent_server():
    from livekit.agents import AgentServer
    from livekit.agents.cli.discover import get_import_data

    import agent

    discovered = get_import_data(path=Path(agent.__file__))
    server = getattr(agent, discovered.app_name)
    assert isinstance(server, AgentServer)
    assert server._agent_name == "everyvoice-agent"


def test_environment_settings_control_models_voice_language_and_instructions(monkeypatch):
    from config import Settings

    monkeypatch.setenv("EVERYVOICE_AGENT_NAME", "configured-agent")
    monkeypatch.setenv("EVERYVOICE_LLM_MODEL", "openai/gpt-4.1")
    monkeypatch.setenv("EVERYVOICE_TTS_MODEL", "cartesia/sonic-3.6")
    monkeypatch.setenv("EVERYVOICE_TTS_VOICE", "configured-voice")
    monkeypatch.setenv("EVERYVOICE_STT_LANGUAGE", "fr")
    monkeypatch.setenv("EVERYVOICE_INSTRUCTIONS", "Be concise and calm.")
    settings = Settings.from_env()
    assert settings.agent_name == "configured-agent"
    assert settings.llm_model == "openai/gpt-4.1"
    assert settings.tts_model == "cartesia/sonic-3.6"
    assert settings.tts_voice == "configured-voice"
    assert settings.stt_language == "fr"
    assert settings.instructions == "Be concise and calm."


def test_agent_uses_validated_personality_and_server_instructions():
    from agent import create_assistant
    from config import Settings

    assistant = create_assistant(
        Settings(instructions="Server instruction."), json.dumps({"personality": "Be warm."})
    )
    assert "Server instruction." in assistant.instructions
    assert "Be warm." in assistant.instructions


@pytest.mark.parametrize(
    "metadata",
    ["{", "[]", '{"personality":42}', '{"other":"bad"}', json.dumps({"personality": "x" * 12001})],
    ids=["json", "array", "type", "extra", "oversize"],
)
def test_worker_rejects_invalid_metadata_even_when_dispatch_bypasses_endpoint(metadata):
    from agent import create_assistant
    from config import Settings

    with pytest.raises(ValueError):
        create_assistant(Settings(), metadata)


def test_pipeline_constructs_real_native_inference_models_without_provider_keys(monkeypatch):
    from livekit.agents import inference

    from agent import create_session
    from config import Settings

    for name in ("SPEECHMATICS_API_KEY", "OPENAI_API_KEY", "CARTESIA_API_KEY"):
        monkeypatch.delenv(name, raising=False)
    # AgentSession eagerly opens DNS/TLS in prewarm; suppress only that external IO.
    monkeypatch.setattr(inference.LLM, "prewarm", lambda self, **kwargs: None)

    async def check():
        session = create_session(
            Settings(
                livekit_url="wss://test.livekit.cloud",
                livekit_api_key="test-api-key",
                livekit_api_secret="test-signing-secret-with-at-least-thirty-two-characters",
            )
        )
        assert isinstance(session.stt, inference.STT)
        assert session.stt.model == "speechmatics/linden-1"
        assert isinstance(session.llm, inference.LLM)
        assert session.llm.model == "openai/gpt-4.1-mini"
        assert isinstance(session.tts, inference.TTS)
        assert session.tts.model == "cartesia/sonic-3"
        await session.aclose()
        await session.llm.aclose()

    asyncio.run(check())
