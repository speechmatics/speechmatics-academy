"""Serverless configuration endpoint. Reads process environment only."""

import json
from http.server import BaseHTTPRequestHandler

from runtime_config import public_config


class handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        body = json.dumps(public_config(allow_environment=getattr(self, 'allow_environment_key', False))).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        pass
