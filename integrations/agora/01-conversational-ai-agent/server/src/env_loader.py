"""Load the backend's local dotenv file without overriding deployment env."""

from pathlib import Path

from dotenv import load_dotenv


def load_server_env(server_dir: Path) -> None:
    """Load process environment > server/.env."""
    load_dotenv(server_dir / ".env")
