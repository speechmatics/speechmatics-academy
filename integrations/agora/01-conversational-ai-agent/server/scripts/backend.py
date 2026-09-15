"""Run backend tasks inside the project virtualenv, on any platform.

Package scripts must never name ``venv/bin/python`` (missing on Windows) or
activate the environment (``source`` does not exist in the Bun Shell that
``bun run`` uses on Windows). Everything routes through here instead, which
asks :mod:`python_runtime` for the platform-correct interpreter and calls it
directly.

    python server/scripts/backend.py setup     # create venv + install dev deps
    python server/scripts/backend.py serve     # install runtime deps + start FastAPI
    python server/scripts/backend.py compile   # byte-compile the sources
    python server/scripts/backend.py test      # run pytest
"""

from __future__ import annotations

import argparse
import os
import subprocess
import tempfile
from pathlib import Path

from python_runtime import ensure_venv, venv_python

SERVER_DIR = Path(__file__).resolve().parent.parent
VENV_DIR = SERVER_DIR / "venv"

COMPILE_TARGETS = (
    "src/server.py",
    "src/agent.py",
    "src/env_loader.py",
    "scripts/setup_env.py",
    "scripts/python_runtime.py",
    "scripts/backend.py",
)


def run(args: list[str], env: dict[str, str] | None = None) -> int:
    """Run a command in the server directory, streaming its output."""
    return subprocess.run(args, cwd=SERVER_DIR, env=env, check=False).returncode


def pip_install(python: Path, requirements: str, quiet: bool) -> int:
    # No index is injected: pip resolves its own configuration, so a private
    # index in pip.conf / pip.ini keeps working. An explicit PIP_INDEX_URL in
    # the environment is inherited as-is.
    env = {**os.environ}
    args = [str(python), "-m", "pip", "install"]
    if quiet:
        args.append("-q")
    args += ["-r", requirements]
    return run(args, env=env)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("setup", "serve", "compile", "test"))
    parser.add_argument("--recreate", action="store_true", help="rebuild the virtualenv from scratch")
    parser.add_argument("--no-install", action="store_true", help="skip dependency installation")
    args, extra = parser.parse_known_args()

    try:
        (major, minor), created = ensure_venv(VENV_DIR, args.recreate)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(exc)
        return 1
    if created:
        print(f"Created server/venv with Python {major}.{minor}")

    python = venv_python(VENV_DIR)

    if args.command == "setup":
        return pip_install(python, "requirements-dev.txt", quiet=False)

    if args.command == "serve":
        if not args.no_install:
            code = pip_install(python, "requirements.txt", quiet=True)
            if code != 0:
                return code
        return run([str(python), "src/server.py", *extra])

    if args.command == "compile":
        # PYTHONPYCACHEPREFIX kept out of the tree; /tmp does not exist on Windows.
        cache = Path(tempfile.gettempdir()) / "speechmatics-test-python-pycache"
        env = {**os.environ, "PYTHONPYCACHEPREFIX": str(cache)}
        return run([str(python), "-m", "py_compile", *COMPILE_TARGETS], env=env)

    if args.command == "test":
        # Keep the default path unless a positional target was supplied,
        # so `bun run test:backend -q` still scopes to tests/.
        positionals = [a for a in extra if not a.startswith("-")]
        targets = extra if positionals else ["tests", *extra]
        return run([str(python), "-m", "pytest", *targets])

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
