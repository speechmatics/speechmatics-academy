"""Credential selection for future integration; public config never contains keys."""

import os
from pathlib import Path


class CredentialError(ValueError):
    """A safe machine-readable error without credential material."""


def load_local_environment(path: Path | None = None) -> None:
    """Load only the local app's .env; deployment handlers do not call this."""
    from dotenv import load_dotenv

    load_dotenv(dotenv_path=path or Path(__file__).resolve().parent / ".env", override=False)


def environment_key_allowed(*, allow_environment: bool = False) -> bool:
    return allow_environment or os.environ.get("SPEECHMATICS_ENABLE_ENV_KEY", "").lower() == "true"


def resolve_api_key(provided_key: str = "", *, allow_environment: bool = False) -> str:
    """Use a supplied key first; an empty key uses the server environment."""
    if (
        not isinstance(provided_key, str)
        or len(provided_key) > 8192
        or any(ord(char) < 32 or ord(char) == 127 for char in provided_key)
    ):
        raise CredentialError("invalid_api_key")
    key = provided_key.strip()
    if any(char.isspace() for char in key):
        raise CredentialError("invalid_api_key")
    if not key:
        if not environment_key_allowed(allow_environment=allow_environment):
            raise CredentialError("missing_api_key")
        environment_key = os.environ.get("SPEECHMATICS_API_KEY", "")
        if any(ord(char) < 32 or ord(char) == 127 for char in environment_key):
            raise CredentialError("invalid_api_key")
        key = environment_key.strip()
        if len(key) > 8192 or any(char.isspace() for char in key):
            raise CredentialError("invalid_api_key")
    if not key:
        raise CredentialError("missing_api_key")
    return key


def public_config(*, allow_environment: bool = False) -> dict[str, bool]:
    return {
        "environment_key_configured": environment_key_allowed(allow_environment=allow_environment)
        and bool(os.environ.get("SPEECHMATICS_API_KEY", "").strip()),
        "transcription_available": True,
    }
