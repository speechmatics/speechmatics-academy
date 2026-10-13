"""Stateless scoped Batch token minting. Never handles audio or transcription waits."""

import base64
import hashlib
import hmac
import json
import time
import urllib.error
import urllib.request
import uuid

TOKEN_TTL = 600
COOKIE_TTL = 24 * 60 * 60
COOKIE_NAME = "oak_batch_scope"
MP_URL = "https://mp.speechmatics.com/v1/api_keys?type=batch"
MAX_RESPONSE_BYTES = 16384


class TokenError(Exception):
    def __init__(self, code: str, message: str, status: int = 502):
        super().__init__(code)
        self.code, self.message, self.status = code, message, status


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _sign(payload: str, api_key: str) -> str:
    secret = hmac.new(api_key.encode(), b"oak-consultation-studio/batch-cookie/v1", hashlib.sha256).digest()
    signature = hmac.new(secret, payload.encode(), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(signature).decode().rstrip("=")


def client_scope(cookie: str, api_key: str, *, now: int | None = None) -> tuple[str, str]:
    """Reuse a valid signed scope; invalid, expired or different-key cookies get new scopes."""
    now = int(time.time()) if now is None else now
    try:
        identifier, expiry, signature = cookie.split(".")
        payload = f"{identifier}.{expiry}"
        if (
            str(uuid.UUID(identifier)) == identifier
            and now < int(expiry) <= now + COOKIE_TTL
            and hmac.compare_digest(signature, _sign(payload, api_key))
        ):
            return f"oak-{identifier}", cookie
    except (ValueError, AttributeError):
        pass
    identifier = str(uuid.uuid4())
    payload = f"{identifier}.{now + COOKIE_TTL}"
    return f"oak-{identifier}", f"{payload}.{_sign(payload, api_key)}"


def mint_batch_token(api_key: str, client_ref: str) -> str:
    request = urllib.request.Request(
        MP_URL,
        data=json.dumps({"ttl": TOKEN_TTL, "client_ref": client_ref}).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=15) as response:
            if response.status != 201:
                raise TokenError("token_service_error", "Could not create a temporary transcription key.")
            raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise ValueError("oversize")
        payload = json.loads(raw)
        token = payload.get("key_value") if isinstance(payload, dict) else None
        if not isinstance(token, str) or not token or any(ord(char) < 32 or ord(char) == 127 for char in token):
            raise ValueError("invalid response")
        return token
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            raise TokenError(
                "invalid_api_key", "The API key was rejected or temporary keys are unavailable.", error.code
            ) from None
        if error.code == 429:
            raise TokenError("rate_limited", "Too many requests. Please try again shortly.", 429) from None
        raise TokenError("token_service_error", "Could not create a temporary transcription key.") from None
    except (TimeoutError, urllib.error.URLError, OSError):
        raise TokenError(
            "token_service_unavailable", "The transcription service could not be reached. Please try again.", 502
        ) from None
    except (ValueError, UnicodeDecodeError):
        raise TokenError("token_service_error", "Could not create a temporary transcription key.") from None
