import http.client
import json
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dev_server import create_server
from runtime_config import CredentialError, load_local_environment, public_config, resolve_api_key


class RuntimeConfigTests(unittest.TestCase):
    def test_process_environment_wins(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / ".env"
            path.write_text("SPEECHMATICS_API_KEY=file-test-value\n", encoding="utf-8")
            with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "process-test-value"}, clear=True):
                load_local_environment(path)
                self.assertEqual(resolve_api_key(allow_environment=True), "process-test-value")

    def test_local_file_loaded(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / ".env"
            path.write_text('SPEECHMATICS_API_KEY="file-test-value"\n', encoding="utf-8")
            with patch.dict(os.environ, {}, clear=True):
                load_local_environment(path)
                self.assertEqual(resolve_api_key(allow_environment=True), "file-test-value")

    def test_empty_environment_keeps_samples_available(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(
                public_config(allow_environment=True),
                {"environment_key_configured": False, "transcription_available": True},
            )

    def test_config_has_no_secret(self):
        with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "private-test-value"}, clear=True):
            self.assertEqual(
                public_config(allow_environment=True),
                {"environment_key_configured": True, "transcription_available": True},
            )

    def test_supplied_key_wins_and_blank_falls_back(self):
        with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "server-test-value"}, clear=True):
            self.assertEqual(resolve_api_key(" ui-test-value "), "ui-test-value")
            self.assertEqual(resolve_api_key(allow_environment=True), "server-test-value")
            self.assertEqual(resolve_api_key("   ", allow_environment=True), "server-test-value")

    def test_invalid_supplied_key_never_falls_back(self):
        with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "server-test-value"}, clear=True):
            for key in (
                "private-test-value\n",
                "\tprivate-test-value",
                "test\x00value",
                "test\x7fvalue",
                "test value",
                "x" * 8193,
                42,
                None,
            ):
                with self.subTest(key_type=type(key).__name__):
                    with self.assertRaisesRegex(CredentialError, "^invalid_api_key$"):
                        resolve_api_key(key)

    def test_invalid_environment_key_is_safe(self):
        with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "private-test-value\n"}, clear=True):
            with self.assertRaisesRegex(CredentialError, "^invalid_api_key$"):
                resolve_api_key(allow_environment=True)

    def test_missing_environment_key_is_safe(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(CredentialError, "^missing_api_key$"):
                resolve_api_key(allow_environment=True)

    def test_http_config_and_static_boundaries(self):
        with tempfile.TemporaryDirectory() as folder:
            public = Path(folder) / "public"
            public.mkdir()
            (public / "index.html").write_text("sample-page", encoding="utf-8")
            (Path(folder) / ".env").write_text("outside-private-test-value", encoding="utf-8")
            (public / ".hidden").write_text("hidden-test-value", encoding="utf-8")
            server = create_server(0, public)
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port)
            try:
                with patch.dict(os.environ, {"SPEECHMATICS_API_KEY": "private-test-value"}, clear=True):
                    connection.request("GET", "/api/config")
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.getheader("Cache-Control"), "no-store")
                    self.assertEqual(
                        json.loads(response.read()),
                        {"environment_key_configured": True, "transcription_available": True},
                    )
                connection.request("GET", "/")
                response = connection.getresponse()
                self.assertEqual(response.read(), b"sample-page")
                for route in ("/.env", "/../.env", "/%2e%2e/.env", "/.hidden", "/runtime_config.py"):
                    connection.request("GET", route)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 404)
                    self.assertNotIn(b"private-test-value", response.read())
            finally:
                connection.close()
                server.shutdown()
                server.server_close()
                worker.join()


if __name__ == "__main__":
    unittest.main()
