"""Exercise application-test selection against real, isolated Git histories."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SELECTOR = Path(__file__).resolve().parents[1] / "scripts" / "select_application_tests.py"


class ApplicationSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Academy test")
        self.git("config", "user.email", "academy-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.autocrlf", "false")
        self.write("README.md", "Fixture\n")
        self.initial = self.commit()

    def git(self, *args):
        result = subprocess.run(
            ["git", *args], cwd=self.root, check=True, capture_output=True, text=True, encoding="utf-8"
        )
        return result.stdout.strip()

    def write(self, relative, content="fixture\n"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def commit(self):
        self.git("add", "--all")
        self.git("commit", "--quiet", "-m", "fixture")
        return self.git("rev-parse", "HEAD")

    def select(self, event_name, event, *, root=None, raw_event=None, env_extra=None):
        event_path = Path(self.temp.name) / "event.json"
        event_path.write_text(json.dumps(event) if raw_event is None else raw_event, encoding="utf-8")
        output_path = Path(self.temp.name) / "output"
        output_path.write_text("existing=value\n", encoding="utf-8")
        env = os.environ.copy()
        env.update(
            GITHUB_EVENT_NAME=event_name,
            GITHUB_EVENT_PATH=str(event_path),
            GITHUB_OUTPUT=str(output_path),
            PYTHONDONTWRITEBYTECODE="1",
        )
        env.update(env_extra or {})
        result = subprocess.run(
            [sys.executable, "-B", str(SELECTOR), "--root", str(root or self.root)],
            env=env,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        lines = output_path.read_text(encoding="utf-8").splitlines()
        self.assertEqual(lines[0], "existing=value", "Selection must append to other step outputs")
        self.assertEqual(len(lines), 4)
        outputs = dict(line.split("=", 1) for line in lines[1:])
        self.assertEqual(set(outputs), {"oak", "agora", "flutter"})
        self.assertTrue(all(value in {"true", "false"} for value in outputs.values()))
        self.assertTrue(result.stdout.strip(), "Explain the selection in the workflow log")
        return outputs, result.stdout

    def assert_selection(self, event_name, event, expected, **kwargs):
        outputs, summary = self.select(event_name, event, **kwargs)
        self.assertEqual(outputs, expected, summary)
        return summary

    def test_manual_run_selects_all_without_diff_metadata(self):
        self.assert_selection("workflow_dispatch", {}, {"oak": "true", "agora": "true", "flutter": "true"})

    def test_each_app_selects_only_its_own_job_including_assets_and_dependencies(self):
        cases = [
            ("use-cases/11-oak-consultation-studio/backend/consultation.py", "oak"),
            ("integrations/agora/01-conversational-ai-agent/frontend/assets/café image.svg", "agora"),
            ("use-cases/09-flutter-mobile-transcription/flutter/pubspec.lock", "flutter"),
        ]
        before = self.initial
        for path, app in cases:
            with self.subTest(app=app):
                self.write(path)
                after = self.commit()
                expected = {"oak": "false", "agora": "false", "flutter": "false"}
                expected[app] = "true"
                self.assert_selection("push", {"before": before, "after": after}, expected)
                before = after

    def test_documentation_and_unrelated_examples_do_not_run_applications(self):
        for path in (
            "use-cases/11-oak-consultation-studio/README.md",
            "integrations/agora/01-conversational-ai-agent/backend/notes.MD",
            "use-cases/09-flutter-mobile-transcription/flutter/README.md",
            "use-cases/09-flutter-mobile-transcription/README.md",
            "basics/01-getting-started/main.py",
            "docs/index.yaml",
            "ruff.toml",
        ):
            self.write(path)
        self.assert_selection(
            "push",
            {"before": self.initial, "after": self.commit()},
            {"oak": "false", "agora": "false", "flutter": "false"},
        )

    def test_flutter_language_catalog_also_runs_oak_consumer_tests(self):
        self.write("use-cases/09-flutter-mobile-transcription/flutter/lib/models/lang_catalog.dart")
        self.assert_selection(
            "push",
            {"before": self.initial, "after": self.commit()},
            {"oak": "true", "agora": "false", "flutter": "true"},
        )

    def test_shared_workflow_and_selector_changes_run_all(self):
        before = self.initial
        for path in (
            ".github/workflows/application-tests.yml",
            ".github/scripts/select_application_tests.py",
            ".github/tests/test_application_selection.py",
        ):
            with self.subTest(path=path):
                self.write(path)
                after = self.commit()
                self.assert_selection(
                    "push", {"before": before, "after": after}, {"oak": "true", "agora": "true", "flutter": "true"}
                )
                before = after

    def test_rename_across_applications_runs_both_source_and_destination(self):
        source = self.write("use-cases/11-oak-consultation-studio/backend/moved.py")
        before = self.commit()
        destination = self.root / "integrations/agora/01-conversational-ai-agent/backend/moved.py"
        destination.parent.mkdir(parents=True)
        source.rename(destination)
        self.assert_selection(
            "push",
            {"before": before, "after": self.commit()},
            {"oak": "true", "agora": "true", "flutter": "false"},
        )

    def test_deleted_application_file_still_selects_tests(self):
        path = self.write("use-cases/09-flutter-mobile-transcription/flutter/lib/deleted.dart")
        before = self.commit()
        path.unlink()
        self.assert_selection(
            "push",
            {"before": before, "after": self.commit()},
            {"oak": "false", "agora": "false", "flutter": "true"},
        )

    def test_pull_request_uses_merge_base_and_ignores_new_changes_on_target_branch(self):
        self.git("branch", "feature")
        self.write("use-cases/09-flutter-mobile-transcription/flutter/lib/target_only.dart")
        target = self.commit()
        self.git("checkout", "--quiet", "feature")
        self.write("use-cases/11-oak-consultation-studio/backend/feature.py")
        feature = self.commit()
        self.assert_selection(
            "pull_request",
            {"pull_request": {"base": {"sha": target}, "head": {"sha": feature}}},
            {"oak": "true", "agora": "false", "flutter": "false"},
        )

    def test_push_includes_all_commits_between_before_and_after(self):
        self.write("use-cases/11-oak-consultation-studio/backend/first.py")
        self.commit()
        self.write("integrations/agora/01-conversational-ai-agent/backend/second.py")
        self.assert_selection(
            "push",
            {"before": self.initial, "after": self.commit()},
            {"oak": "true", "agora": "true", "flutter": "false"},
        )

    def test_invalid_or_unavailable_revisions_conservatively_run_all(self):
        cases = [
            ("push", {}),
            ("push", {"before": "0" * 40, "after": self.initial}),
            ("push", {"before": "a" * 64, "after": self.initial}),
            ("push", {"before": "--output=should-not-exist", "after": self.initial}),
            ("push", {"before": self.initial, "after": []}),
            ("pull_request", {"pull_request": {"base": {"sha": self.initial}}}),
            ("pull_request", {"pull_request": {"base": None, "head": {"sha": self.initial}}}),
            ("pull_request", []),
        ]
        for event_name, event in cases:
            with self.subTest(event_name=event_name, event=event):
                summary = self.assert_selection(event_name, event, {"oak": "true", "agora": "true", "flutter": "true"})
                self.assertIn("all", summary.lower())
                self.assertIn("unavailable", summary.lower())

    def test_unreadable_event_data_conservatively_runs_all(self):
        for raw_event in ("{invalid", "null"):
            with self.subTest(raw_event=raw_event):
                summary = self.assert_selection(
                    "push", {}, {"oak": "true", "agora": "true", "flutter": "true"}, raw_event=raw_event
                )
                self.assertIn("unavailable", summary.lower())

    def test_missing_git_or_invalid_repository_conservatively_runs_all(self):
        event = {"before": self.initial, "after": self.initial}
        for kwargs in ({"root": Path(self.temp.name)}, {"env_extra": {"PATH": ""}}):
            with self.subTest(kwargs=kwargs):
                summary = self.assert_selection(
                    "push", event, {"oak": "true", "agora": "true", "flutter": "true"}, **kwargs
                )
                self.assertIn("unavailable", summary.lower())


if __name__ == "__main__":
    unittest.main()
