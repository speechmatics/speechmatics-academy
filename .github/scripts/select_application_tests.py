#!/usr/bin/env python3
"""Select offline application tests from a GitHub event and local Git history."""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

APP_PATHS = {
    "oak": "use-cases/11-oak-consultation-studio/",
    "agora": "integrations/agora/01-conversational-ai-agent/",
    "flutter": "use-cases/09-flutter-mobile-transcription/flutter/",
}
SHARED_CI_PATHS = {
    ".github/workflows/application-tests.yml",
    ".github/scripts/select_application_tests.py",
    ".github/tests/test_application_selection.py",
}
# Oak's language-preferences tests compare their catalog with this Flutter source.
OAK_LANGUAGE_DEPENDENCY = "use-cases/09-flutter-mobile-transcription/flutter/lib/models/lang_catalog.dart"


class DiffUnavailable(Exception):
    """Changed paths cannot be determined safely; run all application tests."""


def event_revision(event, *keys):
    value = event
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            raise DiffUnavailable("event revision metadata is missing")
        value = value[key]
    if not isinstance(value, str) or not re.fullmatch(r"(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})", value):
        raise DiffUnavailable("event revision metadata is not a full Git SHA")
    return value


def git(root, *args):
    try:
        result = subprocess.run(["git", *args], cwd=root, capture_output=True, check=True, timeout=30)
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise DiffUnavailable("local Git history could not be read") from error
    return result.stdout


def changed_paths(root, event_name):
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        raise DiffUnavailable("GITHUB_EVENT_PATH is missing")
    try:
        event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        raise DiffUnavailable("event JSON could not be read") from error

    if event_name == "pull_request":
        before = event_revision(event, "pull_request", "base", "sha")
        after = event_revision(event, "pull_request", "head", "sha")
        # Exclude changes added to the target branch after the PR diverged.
        revision_range = f"{before}...{after}"
    elif event_name == "push":
        before = event_revision(event, "before")
        after = event_revision(event, "after")
        revision_range = f"{before}..{after}"
    else:
        raise DiffUnavailable("the event does not provide a supported comparison")

    try:
        root = root.resolve(strict=True)
        actual_root = Path(git(root, "rev-parse", "--show-toplevel").decode("utf-8").strip()).resolve(strict=True)
    except (OSError, UnicodeError) as error:
        raise DiffUnavailable("the repository root could not be resolved") from error
    if actual_root != root:
        raise DiffUnavailable("the selected path is not the repository root")
    for revision in (before, after):
        if git(root, "cat-file", "-t", revision).strip() != b"commit":
            raise DiffUnavailable("an event revision is not a commit")
    paths = git(
        root, "diff", "--no-ext-diff", "--no-textconv", "--name-only", "-z", "--no-renames", revision_range, "--"
    )
    # NUL separators preserve spaces, Unicode, and newlines in Git paths.
    # Disabling rename detection includes both the old and new application path.
    return [path.decode("utf-8", errors="surrogateescape") for path in paths.split(b"\0") if path]


def select_applications(root, event_name):
    if event_name == "workflow_dispatch":
        return dict.fromkeys(APP_PATHS, True), "Manual run: running all application tests."
    try:
        paths = changed_paths(root, event_name)
    except DiffUnavailable as error:
        return dict.fromkeys(APP_PATHS, True), f"Diff unavailable ({error}); running all application tests."
    if SHARED_CI_PATHS.intersection(paths):
        return dict.fromkeys(APP_PATHS, True), "Application CI configuration changed: running all application tests."

    selected = dict.fromkeys(APP_PATHS, False)
    for path in paths:
        if path.lower().endswith(".md"):
            continue
        for app, prefix in APP_PATHS.items():
            if path.startswith(prefix):
                selected[app] = True
        if path == OAK_LANGUAGE_DEPENDENCY:
            selected["oak"] = True
    names = ", ".join(app for app, enabled in selected.items() if enabled)
    return selected, f"Compared {len(paths)} changed paths. Selected application tests: {names or 'none'}."


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root (defaults to this checkout)",
    )
    args = parser.parse_args(argv)
    selected, summary = select_applications(args.root, os.environ.get("GITHUB_EVENT_NAME", ""))
    print(summary)
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        print("GITHUB_OUTPUT must be set to the workflow output file.", file=sys.stderr)
        return 1
    try:
        with Path(output).open("a", encoding="utf-8", newline="\n") as handle:
            for app, enabled in selected.items():
                handle.write(f"{app}={str(enabled).lower()}\n")
    except OSError as error:
        print(f"Could not write application selection outputs: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
