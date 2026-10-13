import http.client
import io
import json
import os
import sys
import threading
import unittest
import urllib.error
from email.message import Message
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from api.token import handler
from runtime_config import CredentialError, public_config, resolve_api_key
from token_service import MP_URL, TokenError, client_scope, mint_batch_token


class TokenServiceTests(unittest.TestCase):
    def test_partial_local_body_has_bounded_timeout(self):
        request = MagicMock()
        request.allow_environment_key = True
        request.headers = Message()
        for name, value in {
            "Host": "localhost:4173",
            "Origin": "http://localhost:4173",
            "Content-Type": "application/json",
            "Content-Length": "2",
        }.items():
            request.headers[name] = value
        request.rfile.read.side_effect = TimeoutError("private-test-key")
        with patch("api.token.handler.send_json") as send, patch("api.token.mint_batch_token") as mint:
            handler.do_POST(request)
            request.connection.settimeout.assert_called_once_with(10)
            self.assertEqual(send.call_args.args[1], 408)
            self.assertNotIn("private-test-key", json.dumps(send.call_args.args[2]))
            mint.assert_not_called()

    def test_scope_stable_and_signature_scoped_to_key(self):
        scope, cookie = client_scope("", "test-key", now=100)
        self.assertEqual(client_scope(cookie, "test-key", now=101), (scope, cookie))
        self.assertNotEqual(client_scope(cookie, "different-key", now=101)[0], scope)
        self.assertNotEqual(client_scope(cookie + "tamper", "test-key", now=101)[0], scope)
        self.assertNotEqual(client_scope(cookie, "test-key", now=100 + 604800)[0], scope)

    def test_mint_protocol(self):
        response = MagicMock()
        response.status = 201
        response.read.return_value = b'{"key_value":"temporary-test-token"}'
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value = response
        with patch("token_service.urllib.request.build_opener", return_value=opener):
            self.assertEqual(mint_batch_token("private-test-key", "test-client"), "temporary-test-token")
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, MP_URL)
        self.assertEqual(json.loads(request.data), {"ttl": 600, "client_ref": "test-client"})
        self.assertEqual(opener.open.call_args.kwargs["timeout"], 15)
        response.read.assert_called_once_with(16385)

    def test_errors_do_not_echo_upstream(self):
        errors = [
            (status, urllib.error.HTTPError(MP_URL, status, "private-test-key", {}, io.BytesIO(b"private-test-key")))
            for status in (401, 403, 429, 500, 302)
        ]
        errors += [(502, TimeoutError("private-test-key")), (502, urllib.error.URLError("private-test-key"))]
        for status, upstream_error in errors:
            opener = MagicMock()
            opener.open.side_effect = upstream_error
            with self.subTest(status=status), patch("token_service.urllib.request.build_opener", return_value=opener):
                with self.assertRaises(TokenError) as error:
                    mint_batch_token("private-test-key", "test-client")
                self.assertEqual(error.exception.status, status if status in (401, 403, 429) else 502)
                self.assertNotIn("private-test-key", str(error.exception) + error.exception.message)

    def test_invalid_responses(self):
        for content in (b"x" * 16385, b"not json", b"[]", b'{"key_value":""}'):
            opener = MagicMock()
            response = opener.open.return_value.__enter__.return_value
            response.status = 201
            response.read.return_value = content
            with patch("token_service.urllib.request.build_opener", return_value=opener):
                with self.assertRaises(TokenError):
                    mint_batch_token("test-key", "test-client")

    def test_environment_policy(self):
        with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "server-test-key"}, clear=True):
            with self.assertRaises(CredentialError):
                resolve_api_key()
            self.assertEqual(resolve_api_key(allow_environment=True), "server-test-key")
            self.assertFalse(public_config()["environment_key_configured"])
            os.environ["SPEECHMATICS_ENABLE_ENV_KEY"] = "true"
            self.assertEqual(resolve_api_key(), "server-test-key")
            self.assertTrue(public_config()["environment_key_configured"])
            self.assertEqual(resolve_api_key("browser-test-key"), "browser-test-key")


class TokenHTTPTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port)
        self.origin = f"http://127.0.0.1:{self.server.server_port}"
        self.environment = patch.dict(os.environ, {}, clear=True)
        self.environment.start()

    def tearDown(self):
        self.connection.close()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.environment.stop()

    def post(self, body="{}", headers=None):
        request_headers = {
            "Origin": self.origin,
            "Content-Type": "application/json",
            "Authorization": "Bearer browser-test-key",
        }
        request_headers.update(headers or {})
        self.connection.request("POST", "/api/token", body, request_headers)
        response = self.connection.getresponse()
        return response.status, dict(response.getheaders()), json.loads(response.read())

    def test_success_renewal_and_concurrent_cookie_reuse(self):
        with patch("api.token.mint_batch_token", return_value="temporary-test-token") as mint:
            status, headers, body = self.post()
            self.assertEqual(status, 200)
            self.assertEqual(body, {"token": "temporary-test-token", "expires_in": 600})
            self.assertEqual(headers["Cache-Control"], "no-store")
            self.assertIn("HttpOnly; SameSite=Strict", headers["Set-Cookie"])
            self.assertIn("Path=/api", headers["Set-Cookie"])
            cookie = headers["Set-Cookie"].split(";")[0]
            scope = mint.call_args.args[1]
            for _ in range(2):
                self.assertEqual(self.post(headers={"Cookie": cookie})[0], 200)
                self.assertEqual(mint.call_args.args[1], scope)

    def test_body_and_origin_rejections_never_call_upstream(self):
        with patch("api.token.mint_batch_token") as mint:
            self.assertEqual(self.post(headers={"Origin": "https://other.example"})[0], 403)
            self.assertEqual(self.post('{"client_ref":"someone-else"}')[0], 400)
            self.assertEqual(self.post("[")[0], 400)
            self.assertEqual(self.post("x" * 16385)[0], 413)
            self.assertEqual(self.post(headers={"Authorization": "Bearer "})[0], 400)
            self.assertEqual(self.post(headers={"Authorization": "Bearer invalid key"})[0], 400)
            self.assertEqual(self.post(headers={"Authorization": "Bearer " + "x" * 8193})[0], 400)
            self.assertEqual(self.post(headers={"Cookie": "x=" + "y" * 4096})[0], 413)
            mint.assert_not_called()

    def test_local_host_cannot_be_rebound(self):
        from dev_server import create_server

        local = create_server(0)
        thread = threading.Thread(target=local.serve_forever, daemon=True)
        thread.start()
        connection = http.client.HTTPConnection("127.0.0.1", local.server_port)
        try:
            os.environ["SPEECHMATICS_API_KEY"] = "server-test-key"
            with patch("api.token.mint_batch_token") as mint:
                connection.request(
                    "POST",
                    "/api/token",
                    "{}",
                    {"Host": "evil.example", "Origin": "http://evil.example", "Content-Type": "application/json"},
                )
                response = connection.getresponse()
                self.assertEqual(response.status, 403)
                response.read()
                mint.assert_not_called()
        finally:
            connection.close()
            local.shutdown()
            local.server_close()
            thread.join()

    def test_different_key_tabs_keep_independent_scopes(self):
        with patch("api.token.mint_batch_token", return_value="temporary-test-token") as mint:
            _, headers, _ = self.post()
            first_cookie = headers["Set-Cookie"].split(";")[0]
            first_scope = mint.call_args.args[1]
            _, headers, _ = self.post(headers={"Cookie": first_cookie, "Authorization": "Bearer other-test-key"})
            second_cookie = headers["Set-Cookie"].split(";")[0]
            second_scope = mint.call_args.args[1]
            self.assertNotEqual(first_cookie.split("=")[0], second_cookie.split("=")[0])
            self.assertNotEqual(first_scope, second_scope)
            combined = first_cookie + "; " + second_cookie
            self.assertEqual(self.post(headers={"Cookie": combined})[0], 200)
            self.assertEqual(mint.call_args.args[1], first_scope)
            self.assertEqual(self.post(headers={"Cookie": combined, "Authorization": "Bearer other-test-key"})[0], 200)
            self.assertEqual(mint.call_args.args[1], second_scope)

    def test_remote_environment_disabled_then_opted_in(self):
        os.environ["SPEECHMATICS_API_KEY"] = "server-test-key"
        with patch("api.token.mint_batch_token", return_value="temporary-test-token") as mint:
            self.assertEqual(self.post(headers={"Authorization": ""})[0], 400)
            mint.assert_not_called()
            os.environ["SPEECHMATICS_ENABLE_ENV_KEY"] = "true"
            self.assertEqual(self.post(headers={"Authorization": ""})[0], 200)
            self.assertEqual(mint.call_args.args[0], "server-test-key")

    def test_https_forwarded_origin_and_secure_cookie(self):
        os.environ["VERCEL"] = "1"
        with patch("api.token.mint_batch_token", return_value="temporary-test-token"):
            status, headers, _ = self.post(
                headers={
                    "Origin": "https://studio.example",
                    "X-Forwarded-Host": "studio.example",
                    "X-Forwarded-Proto": "https",
                }
            )
            self.assertEqual(status, 200)
            self.assertIn("; Secure", headers["Set-Cookie"])


if __name__ == "__main__":
    unittest.main()
