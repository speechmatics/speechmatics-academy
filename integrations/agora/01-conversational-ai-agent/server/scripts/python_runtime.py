"""Select a supported Python and manage the quickstart virtual environment.

Layout note: CPython creates ``venv/bin/python`` on macOS and Linux but
``venv/Scripts/python.exe`` on Windows. Every path in this module goes through
``venv_python()`` so the rest of the project never has to care.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

MIN_VERSION = (3, 10)
IS_WINDOWS = os.name == "nt"

# ``sys.executable`` is the interpreter already running this script, so it is
# guaranteed to exist on every platform. The named fallbacks cover the case
# where this module is invoked through a shim that resolved a different Python.
CANDIDATES = (
    sys.executable,
    "python3.14",
    "python3.13",
    "python3.12",
    "python3.11",
    "python3.10",
    "python3",
    "python",
)


def venv_python(venv_dir: Path) -> Path:
    """Return the interpreter path inside ``venv_dir`` for the current platform."""
    if IS_WINDOWS:
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def python_version(executable: str | Path) -> Optional[Tuple[int, int]]:
    try:
        result = subprocess.run(
            [str(executable), "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"],
            capture_output=True,
            check=False,
            text=True,
        )
    except OSError:
        # Missing, unreadable, or not a runnable binary for this machine.
        return None
    if result.returncode != 0:
        return None
    try:
        major, minor = result.stdout.strip().split(".", 1)
        return int(major), int(minor)
    except ValueError:
        return None


def select_python() -> Tuple[str, Tuple[int, int]]:
    configured = os.getenv("QUICKSTART_PYTHON")
    names = (configured, *CANDIDATES) if configured else CANDIDATES
    seen: set[str] = set()
    for name in names:
        if not name:
            continue
        executable = str(name) if os.path.isabs(str(name)) else shutil.which(str(name))
        if not executable or executable in seen:
            continue
        seen.add(executable)
        version = python_version(executable)
        if version and version >= MIN_VERSION:
            return executable, version
    raise RuntimeError(
        f"Python {MIN_VERSION[0]}.{MIN_VERSION[1]} or newer is required; "
        "set QUICKSTART_PYTHON to a supported interpreter"
    )


def check_venv(venv_dir: Path) -> Tuple[int, int]:
    executable = venv_python(venv_dir)
    version = python_version(executable) if executable.exists() else None
    if version is None:
        raise RuntimeError(f"No usable interpreter at {executable}; run: bun run setup:backend --recreate")
    if version < MIN_VERSION:
        raise RuntimeError(
            f"{executable} is Python {version[0]}.{version[1]}, but "
            f"{MIN_VERSION[0]}.{MIN_VERSION[1]}+ is required; "
            "run: bun run setup:backend --recreate"
        )
    return version


def ensure_venv(venv_dir: Path, recreate: bool) -> Tuple[Tuple[int, int], bool]:
    """Create ``venv_dir`` if needed and return ((major, minor), created).

    A healthy virtualenv is never rebuilt. One that exists but is unusable is
    only deleted when it has no interpreter at all, or when ``recreate`` is
    explicitly requested -- deleting a populated environment silently would
    throw away every installed dependency.
    """
    if not recreate:
        try:
            return check_venv(venv_dir), False
        except RuntimeError:
            if venv_dir.exists() and venv_python(venv_dir).exists():
                raise
    executable, _ = select_python()
    if venv_dir.exists():
        other = venv_dir / ("bin" if IS_WINDOWS else "Scripts")
        if not recreate and other.is_dir():
            raise RuntimeError(
                f"{venv_dir} was created on a different operating system "
                f"({other.name}/ layout). Run: bun run setup:backend --recreate"
            )
        shutil.rmtree(venv_dir)
    subprocess.run([executable, "-m", "venv", str(venv_dir)], check=True)
    return check_venv(venv_dir), True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-venv", action="store_true")
    parser.add_argument("--ensure-venv", action="store_true")
    parser.add_argument("--recreate", action="store_true")
    parser.add_argument(
        "--venv-python",
        action="store_true",
        help="print the platform-correct interpreter path inside server/venv and exit",
    )
    args = parser.parse_args()

    server_dir = Path(__file__).resolve().parent.parent
    venv_dir = server_dir / "venv"

    if args.venv_python:
        print(venv_python(venv_dir))
        return 0

    try:
        executable, available_version = select_python()
        print(f"Supported Python available: {executable} ({available_version[0]}.{available_version[1]})")
        if args.check_venv:
            version = check_venv(venv_dir)
            print(f"Backend venv uses Python {version[0]}.{version[1]}")
        if args.ensure_venv:
            version, created = ensure_venv(venv_dir, args.recreate)
            state = "created" if created else "already ready"
            print(f"Backend venv {state} with Python {version[0]}.{version[1]}")
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(exc)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
