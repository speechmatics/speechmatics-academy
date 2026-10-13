"""POST /api/token: optional caller Bearer key, empty JSON, scoped temporary Batch token."""

import json
import os
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlsplit

from runtime_config import CredentialError, resolve_api_key
from token_service import COOKIE_NAME, COOKIE_TTL, TOKEN_TTL, TokenError, client_scope, mint_batch_token

MAX_BODY_BYTES = 16384
MAX_COOKIE_BYTES = 4096
MAX_SCOPE_COOKIES = 32


class handler(BaseHTTPRequestHandler):
    def request_origin(self) -> str:
        host = self.headers.get("Host", "")
        scheme = "http"
        local_context = getattr(self, "allow_environment_key", False)
        if os.environ.get("VERCEL") == "1" and not local_context:
            host = self.headers.get("X-Forwarded-Host", host)
            scheme = self.headers.get("X-Forwarded-Proto", "https")
        if scheme not in ("http", "https") or not host or any(char in host for char in "/\\, \r\n"):
            raise TokenError("invalid_origin", "This request origin is not allowed.", 403)
        if local_context:
            try:
                hostname = urlsplit(f"http://{host}").hostname
            except ValueError:
                hostname = None
            if hostname not in ("127.0.0.1", "localhost", "::1"):
                raise TokenError("invalid_origin", "This request origin is not allowed.", 403)
        return f"{scheme}://{host}"

    def do_POST(self) -> None:
        try:
            expected_origin = handler.request_origin(self)
            if self.headers.get("Origin", "") != expected_origin:
                raise TokenError("invalid_origin", "This request origin is not allowed.", 403)
            if self.headers.get("Transfer-Encoding"):
                raise TokenError("invalid_request", "Send an empty JSON object.", 400)
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                raise TokenError("invalid_request", "Send an empty JSON object.", 400) from None
            if not 0 <= length <= MAX_BODY_BYTES:
                raise TokenError("request_too_large", "The request is too large.", 413)
            if length:
                if self.headers.get_content_type() != "application/json":
                    raise TokenError("invalid_request", "Send an empty JSON object.", 400)
                try:
                    if getattr(self, "allow_environment_key", False):
                        self.connection.settimeout(10)
                    body = json.loads(self.rfile.read(length))
                except (TimeoutError, OSError):
                    raise TokenError("request_timeout", "The request body was not received in time.", 408) from None
                except (ValueError, UnicodeDecodeError):
                    raise TokenError("invalid_request", "Send an empty JSON object.", 400) from None
                if not isinstance(body, dict) or body:
                    raise TokenError("invalid_request", "Send an empty JSON object.", 400)
            authorization = self.headers.get("Authorization", "")
            provided_key = ""
            if authorization:
                if not authorization.startswith("Bearer ") or not authorization[7:].strip():
                    raise CredentialError("invalid_api_key")
                provided_key = authorization[7:]
            api_key = resolve_api_key(provided_key, allow_environment=getattr(self, "allow_environment_key", False))
            cookies = SimpleCookie()
            raw_cookies = self.headers.get("Cookie", "")
            if len(raw_cookies.encode("utf-8")) > MAX_COOKIE_BYTES:
                raise TokenError("request_too_large", "The request is too large.", 413)
            try:
                cookies.load(raw_cookies)
            except CookieError:
                pass
            candidates = [item.value for name, item in cookies.items() if name.startswith(COOKIE_NAME + "_")]
            if len(candidates) > MAX_SCOPE_COOKIES:
                raise TokenError("request_too_large", "The request is too large.", 413)
            scope, signed_cookie = "", ""
            for candidate in candidates:
                candidate_scope, validated_cookie = client_scope(candidate, api_key)
                if validated_cookie == candidate:
                    scope, signed_cookie = candidate_scope, validated_cookie
                    break
            if not scope:
                scope, signed_cookie = client_scope("", api_key)
            token = mint_batch_token(api_key, scope)
            # A random identifier names the cookie: other API-key tabs keep their own
            # scopes, without publishing a fingerprint derived from a permanent key.
            cookie_name = f"{COOKIE_NAME}_{signed_cookie.split('.', 1)[0]}"
            cookie = f"{cookie_name}={signed_cookie}; Path=/api; Max-Age={COOKIE_TTL}; HttpOnly; SameSite=Strict"
            if expected_origin.startswith("https://"):
                cookie += "; Secure"
            handler.send_json(self, 200, {"token": token, "expires_in": TOKEN_TTL}, cookie)
        except CredentialError as error:
            code = str(error)
            message = (
                "Add a Speechmatics API key in Settings."
                if code == "missing_api_key"
                else "The API key format is invalid."
            )
            handler.send_json(self, 400, {"error": {"code": code, "message": message}})
        except TokenError as error:
            handler.send_json(self, error.status, {"error": {"code": error.code, "message": error.message}})

    def send_json(self, status: int, payload: dict, cookie: str = "") -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        handler.send_json(self, 405, {"error": {"code": "method_not_allowed", "message": "Use POST."}})

    def log_message(self, format: str, *args: object) -> None:
        pass
