#!/usr/bin/env python3
"""Validate community projects using the same catalog YAML/schema/path rules."""

import argparse
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from catalog import REPO_ROOT, CatalogError, load_catalog

SECRET_PATTERNS = [
    re.compile(r"sk-[a-zA-Z0-9]{20,}"),
    re.compile(r"SPEECHMATICS_API_KEY\s*=\s*['\"]sm_[a-zA-Z0-9]+['\"]"),
]
SOURCE_EXTENSIONS = {".py", ".ts", ".js", ".go", ".rs", ".cs"}
SKIP_PARTS = {"venv", ".venv", "node_modules", ".git"}


def check_secrets(project_path, root):
    findings = []
    for file in sorted(project_path.rglob("*")):
        if file.suffix not in SOURCE_EXTENSIONS or SKIP_PARTS.intersection(file.parts):
            continue
        try:
            content = file.read_text(encoding="utf-8", errors="ignore")
        except OSError as error:
            findings.append(f"Cannot scan {file.relative_to(root).as_posix()}: {error}")
            continue
        if any(pattern.search(content) for pattern in SECRET_PATTERNS):
            findings.append(f"Potential hardcoded secret in {file.relative_to(root).as_posix()}")
    return findings


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        data = load_catalog(root)
        projects = [example for example in data["examples"] if example["category"] == "community"]
        errors = []
        for project in projects:
            directory = root / project["path"]
            for filename in ("CONTRIBUTORS.md", ".env.example"):
                if not (directory / filename).is_file():
                    print(f"WARNING: [{project['id']}] missing {filename}")
            errors.extend(check_secrets(directory, root))
        if errors:
            raise CatalogError("\n".join(errors))
        print(f"Community structure check passed: {len(projects)} project(s) validated")
        return 0
    except (CatalogError, OSError) as error:
        print(f"Community structure error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
