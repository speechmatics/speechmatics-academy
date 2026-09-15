import os
from pathlib import Path

from env_loader import load_server_env


def test_env_supplies_local_values(tmp_path: Path, monkeypatch):
    monkeypatch.delenv("AGORA_APP_ID", raising=False)
    monkeypatch.delenv("AGORA_APP_CERTIFICATE", raising=False)
    (tmp_path / ".env").write_text("AGORA_APP_ID=local-app-id\nAGORA_APP_CERTIFICATE=local-certificate\n")

    load_server_env(tmp_path)

    assert os.environ["AGORA_APP_ID"] == "local-app-id"
    assert os.environ["AGORA_APP_CERTIFICATE"] == "local-certificate"


def test_process_env_wins_over_local_files(tmp_path: Path, monkeypatch):
    monkeypatch.setenv("AGORA_APP_ID", "deployment-app-id")
    (tmp_path / ".env").write_text("AGORA_APP_ID=local-app-id\n")

    load_server_env(tmp_path)

    assert os.environ["AGORA_APP_ID"] == "deployment-app-id"
