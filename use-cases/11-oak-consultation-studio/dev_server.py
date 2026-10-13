"""Local static preview and safe runtime configuration: python dev_server.py --port 4173."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import mimetypes
from pathlib import Path
from urllib.parse import unquote, urlsplit

from api.config import handler as ConfigHandler
from api.token import handler as TokenHandler
from runtime_config import load_local_environment

ROOT = Path(__file__).resolve().parent
PUBLIC_DIR = ROOT / 'public'
mimetypes.add_type('text/javascript', '.js')
mimetypes.add_type('text/css', '.css')


class StudioHandler(SimpleHTTPRequestHandler):
    allow_environment_key = True

    def _safe_static_path(self) -> bool:
        path = unquote(urlsplit(self.path).path).replace('\\', '/')
        parts = path.split('/')
        if any(part.startswith('.') for part in parts if part):
            return False
        root = Path(self.directory).resolve()
        candidate = root.joinpath(*[part for part in parts if part]).resolve()
        return candidate.is_relative_to(root)

    def do_GET(self) -> None:
        if urlsplit(self.path).path == '/api/config':
            ConfigHandler.do_GET(self)
        elif urlsplit(self.path).path == '/api/token':
            TokenHandler.do_GET(self)
        elif self._safe_static_path():
            super().do_GET()
        else:
            self.send_error(404, 'Not Found')

    def do_POST(self) -> None:
        if urlsplit(self.path).path == '/api/token':
            TokenHandler.do_POST(self)
        else:
            self.send_error(404, 'Not Found')

    def do_HEAD(self) -> None:
        if urlsplit(self.path).path == '/api/config':
            self.send_error(405, 'Method Not Allowed')
        elif self._safe_static_path():
            super().do_HEAD()
        else:
            self.send_error(404, 'Not Found')

    def list_directory(self, path: str):
        self.send_error(404, 'Not Found')
        return None

    def end_headers(self) -> None:
        # /api/config sends its own no-store header.
        if urlsplit(self.path).path not in ('/api/config', '/api/token'):
            self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, format: str, *args: object) -> None:
        pass


def create_server(port: int, public_dir: Path = PUBLIC_DIR) -> ThreadingHTTPServer:
    return ThreadingHTTPServer(('127.0.0.1', port), partial(StudioHandler, directory=str(public_dir)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=4173)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error('--port must be between 1 and 65535')
    load_local_environment()
    server = create_server(args.port)
    print(f'Oak Consultation Studio: http://127.0.0.1:{args.port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
