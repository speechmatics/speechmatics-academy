import sys
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parents[1]
if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

from scripts.setup_env import ensure_env, invalid_keys, read_values


def test_setup_env_migrates_legacy_names_and_adds_speechmatics(tmp_path: Path):
    template = tmp_path / ".env.example"
    template.write_text(
        "AGORA_APP_ID=your_agora_app_id\n"
        "AGORA_APP_CERTIFICATE=your_agora_app_certificate\n"
        "SPEECHMATICS_API_KEY=your_speechmatics_api_key\n"
    )
    target = tmp_path / ".env"
    target.write_text("APP_ID=legacy-app-id\nAPP_CERTIFICATE=legacy-certificate\n")

    added, migrated = ensure_env(target, template)
    values = read_values(target)

    assert added == ["SPEECHMATICS_API_KEY"]
    assert migrated == ["AGORA_APP_ID", "AGORA_APP_CERTIFICATE"]
    assert values["AGORA_APP_ID"] == "legacy-app-id"
    assert values["AGORA_APP_CERTIFICATE"] == "legacy-certificate"
    assert values["SPEECHMATICS_API_KEY"] == "your_speechmatics_api_key"
    assert "APP_ID" not in values
    assert "APP_CERTIFICATE" not in values
    assert invalid_keys(target) == ["SPEECHMATICS_API_KEY"]


def test_setup_env_preserves_configured_local_values(tmp_path: Path):
    template = tmp_path / ".env.example"
    template.write_text(
        "AGORA_APP_ID=your_agora_app_id\n"
        "AGORA_APP_CERTIFICATE=your_agora_app_certificate\n"
        "SPEECHMATICS_API_KEY=your_speechmatics_api_key\n"
    )
    target = tmp_path / ".env"
    target.write_text(
        "AGORA_APP_ID=local-app-id\n"
        "AGORA_APP_CERTIFICATE=local-certificate\n"
        "SPEECHMATICS_API_KEY=local-speechmatics-key\n"
    )

    added, migrated = ensure_env(target, template)

    assert added == []
    assert migrated == []
    assert invalid_keys(target) == []
    assert read_values(target)["AGORA_APP_ID"] == "local-app-id"
