"""Offline catalog behavior checks; fixtures never use the real examples or APIs."""

import copy
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from catalog import note_text, render_catalog, render_hub, render_llms, render_root_table


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = {
            "version": "2.0.0",
            "last_updated": "2026-10-21",
            "categories": [
                {"id": "basics", "title": "Basics", "description": "Learn"},
                {"id": "integrations", "title": "Integrations", "description": "Connect"},
                {"id": "use-cases", "title": "Use Cases", "description": "Build"},
            ],
            "difficulty_levels": ["beginner", "intermediate"],
            "languages": ["python", "typescript", "config"],
            "language_labels": {"python": "Python", "typescript": "TypeScript", "config": "Configuration"},
            "features": ["transcription"],
            "feature_labels": {"transcription": "Transcription"},
            "packages": [
                {
                    "id": "sdk",
                    "title": "SDK | client",
                    "label": "sdk|client",
                    "url": "https://example.org/sdk",
                    "lifecycle": "current",
                }
            ],
            "apis": [
                {"id": "realtime", "title": "Real-time", "url": "https://example.org/api"},
                {
                    "id": "voice-preview",
                    "title": "Voice API preview (legacy protocol)",
                    "url": "https://example.org/old",
                },
            ],
            "collections": [
                {
                    "id": "healthcare",
                    "title": "Healthcare",
                    "description": "Medical",
                    "readme": "collections/healthcare/README.md",
                    "start_here": "first",
                }
            ],
            "integration_frameworks": [
                {
                    "id": "livekit",
                    "title": "LiveKit",
                    "url": "https://example.org/livekit",
                    "kind": "framework",
                    "readme": "integrations/livekit/README.md",
                    "start_here": "first",
                }
            ],
            "examples": [
                self.example("first", "basics/01-first", 1),
                self.example("second", "integrations/new-framework/01-second", 2),
            ],
        }
        self.data["examples"][1].update(
            packages=[], languages=["config"], kind="configuration", lifecycle="legacy", apis=["voice-preview"]
        )
        self.write(
            "README.md",
            "AUTHORED BEFORE\n"
            + "\n".join(self.block(n) for n in ("basics", "integrations", "use-cases"))
            + "\nAUTHORED AFTER\n",
        )
        for hub in ("collections/healthcare/README.md", "integrations/livekit/README.md"):
            self.write(hub, "HUB INTRO\n" + self.block("examples") + "\nHUB END\n")
        for ex in self.data["examples"]:
            self.write(ex["path"] + "/README.md", "# Local example\n\n## Run\n")
        self.save()

    @staticmethod
    def block(name):
        return f"<!-- BEGIN GENERATED: {name} -->\nold\n<!-- END GENERATED: {name} -->"

    @staticmethod
    def example(identifier, path, order):
        return {
            "id": identifier,
            "title": "Build [voice] | <agent>",
            "description": "A pipe | and <script> & useful details.",
            "category": "basics" if order == 1 else "integrations",
            "difficulty": "beginner",
            "languages": ["python", "typescript"],
            "features": ["transcription"],
            "integrations": ["livekit"],
            "path": path,
            "tags": ["voice"],
            "last_updated": "2026-10-20",
            "estimated_time": "10 minutes",
            "packages": ["sdk"],
            "apis": ["realtime"],
            "collections": ["healthcare"],
            "lifecycle": "current",
            "kind": "code",
            "order": order,
            "demos": [
                {"type": "local", "url": path + "/README.md#run", "description": "Requires credentials"},
                {
                    "type": "recording",
                    "url": "https://example.org/watch?a=1&b=2",
                    "description": "Recorded walkthrough",
                },
            ],
        }

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")

    def save(self):
        self.write("docs/index.yaml", yaml.safe_dump(self.data, sort_keys=False))

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPTS / "generate_catalog.py"), "--root", str(self.root), *args],
            text=True,
            capture_output=True,
        )

    def snapshot(self):
        return {
            p.relative_to(self.root).as_posix(): (p.read_bytes(), p.stat().st_mtime_ns)
            for p in self.root.rglob("*")
            if p.is_file()
        }

    def test_generates_cross_membership_links_details_and_escaped_text(self):
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = (self.root / "docs/CATALOG.md").read_text(encoding="utf-8")
        for facet in ("by-package", "by-feature", "by-language", "by-integration", "by-collection", "by-difficulty"):
            self.assertIn(f'id="{facet}"', catalog)
        self.assertIn('id="example-first"', catalog)
        self.assertIn("../basics/01-first/README.md", catalog)
        self.assertIn("A pipe &#124; and &lt;script&gt; &amp; useful details.", catalog)
        self.assertIn("sdk&#124;client", catalog)
        self.assertIn("Python, TypeScript", catalog)
        self.assertIn("Direct API / configuration", catalog)
        self.assertIn("Implementation: legacy", catalog)
        self.assertIn("Service availability", catalog)
        self.assertIn("Recording", catalog)
        root_text = (self.root / "README.md").read_text(encoding="utf-8")
        self.assertTrue(root_text.startswith("AUTHORED BEFORE\n"))
        self.assertTrue(root_text.endswith("AUTHORED AFTER\n"))
        hub = (self.root / "collections/healthcare/README.md").read_text(encoding="utf-8")
        self.assertIn("../../basics/01-first/README.md", hub)
        self.assertIn("../../integrations/new-framework/01-second/README.md", hub)
        llms = (self.root / "llms.txt").read_text(encoding="utf-8")
        self.assertIn("https://github.com/speechmatics/speechmatics-academy/blob/main/basics/01-first/README.md", llms)

    def test_hub_compact_rows_use_summary_and_keep_material_notes_outside_cells(self):
        first = self.data["examples"][0]
        first.update(summary="Short | <outcome>", demo_note="Needs preview access & creates [calendar] events.")
        before = copy.deepcopy(self.data)
        rendered = render_hub(self.data, self.data["collections"][0], "collections")
        table_lines = [line for line in rendered.splitlines() if line.startswith("|")]
        self.assertEqual(table_lines[0], "| Example | What you'll build | SDK / adapter | Language / level | Demo |")
        self.assertTrue(all(len(line.split("|")) == 7 for line in table_lines))
        self.assertIn("Short &#124; &lt;outcome&gt;", table_lines[2])
        self.assertIn("Python, TypeScript<br>beginner", table_lines[2])
        self.assertIn(
            "[Local](<../../basics/01-first/README.md#run>) · [Recording](<https://example.org/watch?a=1&b=2>)",
            table_lines[2],
        )
        self.assertNotIn("Requires credentials", rendered)
        self.assertNotIn("Recorded walkthrough", rendered)
        self.assertNotIn("calendar", "\n".join(table_lines))
        notes = rendered.split("### Demo access\n", 1)[1]
        self.assertIn("[Build &#91;voice&#93; &#124; &lt;agent&gt;](<../../basics/01-first/README.md>)", notes)
        self.assertIn("Needs preview access &amp; creates &#91;calendar&#93; events.", notes)
        self.assertNotIn("Implementation: current", rendered)
        self.assertIn("**Legacy**", table_lines[3])
        self.assertIn("A pipe &#124; and &lt;script&gt; &amp; useful details.", table_lines[3])
        self.assertEqual(self.data, before)

    def test_fundamentals_use_compact_summaries_and_shared_lifecycle_markers(self):
        first, second = self.data["examples"]
        first.update(summary="Short | <outcome>", lifecycle="preview")
        second.update(category="basics", lifecycle="legacy")
        before = copy.deepcopy(self.data)
        rows = render_root_table(self.data, "basics").splitlines()
        self.assertIn("Short &#124; &lt;outcome&gt;", rows[2])
        self.assertNotIn(first["description"], rows[2])
        self.assertIn("**Preview**", rows[2])
        self.assertIn("**Legacy**", rows[3])
        self.assertNotIn("(preview)", rows[2])
        self.assertIn("A pipe &#124; and &lt;script&gt; &amp; useful details.", rows[3])
        self.assertIn("[sdk&#124;client]", rows[2])
        self.assertTrue(rows[2].endswith("| beginner |"))
        self.assertEqual(self.data, before)

    def test_hub_demo_notes_follow_displayed_lifecycle_groups(self):
        first, second = self.data["examples"]
        first.update(lifecycle="legacy", demo_note="First note")
        second.update(lifecycle="current", demo_note="Second note")
        third = self.example("third", "basics/03-third", 3)
        third.update(lifecycle="preview", demo_note="Third note")
        self.data["examples"].append(third)
        hub = self.data["collections"][0]
        for grouped, expected in (
            (True, ["Second note", "First note", "Third note"]),
            (False, ["First note", "Second note", "Third note"]),
        ):
            with self.subTest(grouped=grouped):
                hub["group_by_lifecycle"] = grouped
                notes = render_hub(self.data, hub, "collections").split("### Demo access\n", 1)[1]
                positions = [notes.index(note) for note in expected]
                self.assertEqual(positions, sorted(positions))

    def test_apis_without_reference_urls_remain_named_without_circular_links(self):
        self.data["apis"][1].pop("url")
        self.data["apis"][1]["title"] = "Voice [API] <preview>"
        hub = self.data["collections"][0]
        rendered = render_hub(self.data, hub, "collections")
        reference = next(line for line in rendered.splitlines() if line.startswith("API reference:"))
        self.assertIn("https://example.org/api", reference)
        self.assertNotIn("preview", reference)
        self.assertNotIn("blob/main", reference)
        details = render_catalog(self.data).split('<a id="all-example-details">', 1)[1]
        self.assertIn("- APIs: Voice &#91;API&#93; &lt;preview&gt;", details)
        self.data["examples"][0]["apis"] = ["voice-preview"]
        rendered = render_hub(self.data, hub, "collections")
        self.assertNotIn("API reference:", rendered)
        self.assertIn("The Voice API preview is a legacy protocol, separate from Agent STT.", rendered)

    def test_schema_allows_missing_api_reference_but_validates_supplied_urls(self):
        self.data["apis"][1].pop("url")
        self.save()
        self.assertEqual(self.cli("--validate-only").returncode, 0)
        for invalid in ("", "basics/01-first/README.md", "http://example.org/docs"):
            with self.subTest(url=invalid):
                self.data["apis"][1]["url"] = invalid
                self.save()
                self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_hub_unique_api_references_and_protocol_note_follow_api_membership(self):
        self.data["examples"][1].update(lifecycle="preview", apis=["realtime"])
        hub = self.data["collections"][0]
        rendered = render_hub(self.data, hub, "collections")
        self.assertEqual(rendered.count("https://example.org/api"), 1)
        self.assertNotIn(
            "https://example.org/api", "\n".join(line for line in rendered.splitlines() if line.startswith("|"))
        )
        self.assertNotIn("legacy protocol", rendered)
        self.assertNotIn("### Demo access", rendered)
        self.assertNotIn("Service availability", rendered)
        self.data["examples"][1]["apis"] = ["realtime", "voice-preview"]
        rendered = render_hub(self.data, hub, "collections")
        self.assertEqual(rendered.count("https://example.org/api"), 1)
        self.assertEqual(rendered.count("https://example.org/old"), 1)
        self.assertIn("The Voice API preview is a legacy protocol, separate from Agent STT.", rendered)

    def test_hub_lifecycle_grouping_preserves_each_member_once_and_omits_empty_groups(self):
        third = self.example("third", "use-cases/01-preview", 3)
        third.update(lifecycle="preview", category="use-cases")
        self.data["examples"].append(third)
        for field, hub, second_path in (
            ("collections", self.data["collections"][0], "../../integrations/new-framework/01-second/README.md"),
            ("integrations", self.data["integration_frameworks"][0], "../new-framework/01-second/README.md"),
        ):
            with self.subTest(field=field):
                hub["group_by_lifecycle"] = True
                rendered = render_hub(self.data, hub, field)
                self.assertIn("### Legacy and preview examples\n", rendered)
                current, other = rendered.split("### Legacy and preview examples\n", 1)
                self.assertIn("### Current examples\n", current)
                self.assertEqual(current.count("basics/01-first/README.md>)"), 1)
                self.assertNotIn(second_path + ">)", current)
                self.assertEqual(other.count(second_path + ">)"), 1)
                self.assertEqual(other.count("use-cases/01-preview/README.md>)"), 1)
                self.assertNotIn("basics/01-first/README.md>)", other)
                self.assertIn("**Preview**", other)
                original = copy.deepcopy(self.data["examples"])
                for lifecycle, shown, absent in (
                    ("current", "Current examples", "Legacy and preview examples"),
                    ("legacy", "Legacy and preview examples", "Current examples"),
                ):
                    for example in self.data["examples"]:
                        example["lifecycle"] = lifecycle
                    rendered = render_hub(self.data, hub, field)
                    self.assertIn("### " + shown, rendered)
                    self.assertNotIn("### " + absent, rendered)
                self.data["examples"] = original

    def test_navigation_keeps_community_review_separate_from_implementation_lifecycle(self):
        self.data["examples"][0]["status"] = "verified"
        hub = render_hub(self.data, self.data["collections"][0], "collections")
        facets = render_catalog(self.data).split('<a id="all-example-details">', 1)[0]
        for rendered in (hub, facets):
            self.assertIn("Community review: verified", rendered)
            self.assertNotIn("Implementation: current", rendered)
            self.assertIn("**Legacy**", rendered)

    def test_catalog_omits_empty_facets_but_keeps_existing_anchors_and_full_detail_records(self):
        self.data["languages"].append("csharp")
        self.data["language_labels"]["csharp"] = "C#"
        self.data["examples"][0].update(
            summary="Compact outcome", demo_note="Preview account required.", models=["test-model"]
        )
        rendered = render_catalog(self.data)
        navigation, details = rendered.split('<a id="all-example-details">', 1)
        self.assertNotIn('id="language-csharp"', navigation)
        self.assertNotIn("### C#", navigation)
        self.assertNotIn("No examples currently listed", navigation)
        self.assertIn('id="language-python"', navigation)
        self.assertIn('id="collection-healthcare"', navigation)
        self.assertIn("Compact outcome", navigation)
        self.assertNotIn("| Status |", navigation)
        self.assertNotIn("Implementation: current", navigation)
        self.assertIn("**Legacy**", navigation)
        self.assertEqual(rendered.count("Service availability:"), 1)
        first, second = details.split('<a id="example-second">', 1)
        self.assertEqual(first.count("Build &#91;voice&#93; &#124; &lt;agent&gt;"), 1)
        self.assertNotIn("Compact outcome", first)
        for value in (
            "A pipe &#124; and &lt;script&gt; &amp; useful details.",
            "Implementation: current",
            "kind: code",
            "difficulty: beginner",
            "languages: Python, TypeScript",
            "https://example.org/api",
            "https://example.org/sdk",
            "Transcription",
            "LiveKit",
            "Healthcare",
            "10 minutes",
            "2026-10-20",
            "Requires credentials",
            "Recorded walkthrough",
            "test-model",
            "Preview account required.",
        ):
            self.assertIn(value, first)
        self.assertNotIn("legacy protocol", first)
        self.assertIn("The Voice API preview is a legacy protocol, separate from Agent STT.", second)

    def test_llms_keeps_full_description_and_scopes_protocol_warning_to_relevant_example(self):
        self.data["examples"][0].update(
            summary="Compact outcome", lifecycle="preview", demo_note="Realtime preview access."
        )
        rendered = render_llms(self.data, self.root)
        first = next(line for line in rendered.splitlines() if "blob/main/basics/01-first/README.md" in line)
        second = next(
            line for line in rendered.splitlines() if "blob/main/integrations/new-framework/01-second/README.md" in line
        )
        for value in (
            "A pipe | and <script> & useful details.",
            "Implementation: preview",
            "APIs: Real-time",
            "packages: SDK | client",
            "languages: Python, TypeScript",
            "Realtime preview access.",
        ):
            self.assertIn(value, first)
        self.assertNotIn("Compact outcome", first)
        self.assertNotIn("legacy protocol", first)
        self.assertIn("The Voice API preview is a legacy protocol, separate from Agent STT.", second)
        self.assertEqual(rendered.count("Service availability:"), 1)

    def test_llms_raw_text_preserves_identifiers_punctuation_and_canonical_links(self):
        first = self.data["examples"][0]
        first.update(
            title="Speaker ID & Speaker Focus [guide] `code`",
            description="Use ar_en & speaker_id with the deployment's endpoint.\nSecond line stays in the record.",
            demo_note="Use `ar_en` at `/api/token`; keep literal &amp; text unchanged.",
        )
        self.data["packages"][0]["title"] = "SDK_client & adapters"
        rendered = render_llms(self.data, self.root)
        record = next(line for line in rendered.splitlines() if "blob/main/basics/01-first/README.md" in line)
        self.assertIn(r"[Speaker ID & Speaker Focus \[guide\] \`code\`]", record)
        self.assertIn("ar_en & speaker_id with the deployment's endpoint. Second line", record)
        self.assertIn("Use `ar_en` at `/api/token`", record)
        self.assertIn("packages: SDK_client & adapters", record)
        self.assertIn("literal &amp; text unchanged", record)
        self.assertNotIn("&#", record)
        self.assertNotIn("&amp;amp;", record)
        self.assertEqual(record.count("https://github.com/speechmatics/speechmatics-academy/blob/main/"), 1)

    def test_notes_support_literal_code_spans_without_enabling_html_or_links(self):
        value = "Use `ar_en` and `/api/token`; deployment's key. <img src=x> [unsafe](https://bad.invalid) *literal* ~~deleted~~."
        rendered = note_text(value)
        self.assertIn("Use `ar_en` and `/api/token`; deployment's key.", rendered)
        self.assertIn("&lt;img src=x&gt;", rendered)
        self.assertIn("&#91;unsafe&#93;(https://bad.invalid)", rendered)
        self.assertIn("&#42;literal&#42;", rendered)
        self.assertIn("&#126;&#126;deleted&#126;&#126;", rendered)
        self.assertNotIn("<img", rendered)
        self.assertNotIn("[unsafe]", rendered)
        self.assertEqual(
            note_text("Keep ``literal ` tick`` and `<script> & [x](url)`"),
            "Keep ``literal ` tick`` and `<script> & [x](url)`",
        )
        self.assertEqual(note_text("Use `ends\\` next"), "Use `ends\\` next")
        self.assertEqual(note_text("before  `a  b`  after"), "before `a  b` after")
        self.assertEqual(note_text("unmatched `ar_en"), "unmatched &#96;ar&#95;en")
        self.assertEqual(note_text(r"escaped \`ar_en\`"), "escaped &#92;&#96;ar&#95;en&#92;&#96;")

    def test_note_code_spans_are_rendered_in_hubs_details_and_raw_llms(self):
        self.data["examples"][0]["demo_note"] = "Use `ar_en` and `/api/token`; deployment's API key."
        for rendered in (
            render_hub(self.data, self.data["collections"][0], "collections"),
            render_catalog(self.data),
            render_llms(self.data, self.root),
        ):
            self.assertIn("Use `ar_en` and `/api/token`; deployment's API key.", rendered)
            self.assertNotIn("ar&#95;en", rendered)

    def test_schema_accepts_optional_presentation_fields_and_rejects_wrong_types(self):
        self.data["examples"][0].update(summary="Compact outcome", demo_note="Requires preview access.")
        for registry_name in ("collections", "integration_frameworks"):
            self.data[registry_name][0]["group_by_lifecycle"] = True
        self.save()
        result = self.cli("--validate-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        original = copy.deepcopy(self.data)
        for field, value in (("summary", ""), ("demo_note", [])):
            with self.subTest(field=field):
                self.data = copy.deepcopy(original)
                self.data["examples"][0][field] = value
                self.save()
                self.assertNotEqual(self.cli("--validate-only").returncode, 0)
        for registry_name in ("collections", "integration_frameworks"):
            self.data = copy.deepcopy(original)
            self.data[registry_name][0]["group_by_lifecycle"] = "yes"
            self.save()
            self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_check_is_read_only_for_missing_stale_and_fresh_outputs(self):
        before = self.snapshot()
        self.assertNotEqual(self.cli("--check").returncode, 0)
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.cli().returncode, 0)
        before = self.snapshot()
        self.assertEqual(self.cli("--check").returncode, 0)
        self.assertEqual(before, self.snapshot())
        self.write("docs/CATALOG.md", "stale\n")
        before = self.snapshot()
        self.assertNotEqual(self.cli("--check").returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_repeated_generation_is_deterministic_and_does_not_rewrite(self):
        self.assertEqual(self.cli().returncode, 0)
        before = self.snapshot()
        self.assertEqual(self.cli().returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_bad_marker_never_causes_partial_output_writes(self):
        for mutation in ("missing", "duplicate", "reversed", "nested"):
            with self.subTest(mutation=mutation):
                block = self.block("examples")
                broken = {
                    "missing": "authored",
                    "duplicate": block + block,
                    "reversed": "<!-- END GENERATED: examples -->\n<!-- BEGIN GENERATED: examples -->",
                    "nested": "<!-- BEGIN GENERATED: examples -->\n" + block + "\n<!-- END GENERATED: examples -->",
                }[mutation]
                self.write("integrations/livekit/README.md", broken)
                before = self.snapshot()
                self.assertNotEqual(self.cli().returncode, 0)
                self.assertEqual(before, self.snapshot())

    def test_rejects_duplicate_ids_paths_orders_and_unknown_vocab(self):
        original = copy.deepcopy(self.data)
        for field, value in (
            ("id", "first"),
            ("path", "basics/01-first"),
            ("order", 1),
            ("packages", ["unknown"]),
            ("features", ["unknown"]),
            ("integrations", ["unknown"]),
            ("collections", ["unknown"]),
            ("apis", ["unknown"]),
            ("languages", ["unknown"]),
            ("difficulty", "unknown"),
        ):
            with self.subTest(field=field):
                self.data = copy.deepcopy(original)
                self.data["examples"][1][field] = value
                self.save()
                self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_rejects_yaml_duplicate_keys_and_schema_types(self):
        self.write("docs/index.yaml", "version: '2.0.0'\nversion: 'other'\n")
        result = self.cli("--validate-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate", result.stderr.lower())
        self.data["examples"][0]["order"] = "one"
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_missing_or_orphaned_examples_are_errors_even_for_new_frameworks(self):
        self.write("integrations/unregistered/01-orphan/README.md", "# Orphan")
        result = self.cli("--validate-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("orphan", result.stderr.lower())
        (self.root / "integrations/unregistered/01-orphan/README.md").unlink()
        (self.root / "integrations/unregistered/01-orphan").rmdir()
        (self.root / "basics/01-first/README.md").unlink()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_configuration_and_deep_requirements_are_valid(self):
        self.write("basics/01-first/python/nested/requirements.txt", "some-sdk\n")
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "check_structure.py"), "--root", str(self.root)],
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("requirements", result.stdout.lower())
        self.assertIn("2 examples", result.stdout)

    def test_rejects_traversal_unsafe_urls_and_wrong_hub_start(self):
        original = copy.deepcopy(self.data)
        for mutation in ("path", "demo", "hosted-local", "hub", "id", "missing-demo"):
            with self.subTest(mutation=mutation):
                self.data = copy.deepcopy(original)
                if mutation == "path":
                    self.data["examples"][0]["readme"] = "../outside.md"
                elif mutation == "demo":
                    self.data["examples"][0]["demos"][0]["url"] = "javascript:alert(1)"
                elif mutation == "hosted-local":
                    self.data["examples"][0]["demos"][0].update(type="hosted", url="https://localhost:8000")
                elif mutation == "hub":
                    self.data["collections"][0]["start_here"] = "absent"
                elif mutation == "id":
                    self.data["examples"][0]["id"] = 'bad"<id>'
                else:
                    del self.data["examples"][0]["demos"][0]["description"]
                self.save()
                self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_local_recording_asset_is_valid_and_hosted_local_asset_is_rejected(self):
        self.write("basics/01-first/assets/demo.gif", "GIF fixture")
        demo = self.data["examples"][0]["demos"][1]
        demo["url"] = "basics/01-first/assets/demo.gif"
        self.save()
        self.assertEqual(self.cli("--validate-only").returncode, 0)
        demo["type"] = "hosted"
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_local_fragments_must_exist_with_heading_and_explicit_anchor_support(self):
        self.write(
            "basics/01-first/README.md",
            "# First\n## Run & test `code`\n## Run & test `code`\n<a id='explicit-id'></a>\n",
        )
        demo = self.data["examples"][0]["demos"][0]
        for fragment in ("run--test-code", "run--test-code-1", "explicit-id"):
            demo["url"] = "basics/01-first/README.md#" + fragment
            self.save()
            self.assertEqual(self.cli("--validate-only").returncode, 0, fragment)
        demo["url"] = "basics/01-first/README.md#absent"
        self.save()
        result = self.cli("--validate-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fragment", result.stderr.lower())

    def test_rejects_hub_fragment_and_directory_output_before_any_writes(self):
        self.data["collections"][0]["readme"] += "#intro"
        self.save()
        before = self.snapshot()
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertEqual(before, self.snapshot())
        self.data["collections"][0]["readme"] = "collections/healthcare/README.md"
        self.save()
        (self.root / "llms.txt").mkdir()
        before = self.snapshot()
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertEqual(before, self.snapshot())

    @unittest.skipUnless(sys.platform == "win32", "Windows case-equivalent paths")
    def test_case_equivalent_hub_destinations_are_rejected_without_writes(self):
        self.data["integration_frameworks"][0]["readme"] = "collections/healthcare/readme.md"
        self.data["examples"][1]["collections"] = []
        self.save()
        before = self.snapshot()
        for arguments in (("--validate-only",), ("--check",), ()):
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Hub output path reused", result.stderr)
                self.assertEqual(before, self.snapshot())

    def test_encoded_hub_alias_is_rejected_without_writes(self):
        self.data["integration_frameworks"][0]["readme"] = "collections/healthcare/%52EADME.md"
        self.save()
        before = self.snapshot()
        for arguments in (("--validate-only",), ("--check",), ()):
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Hub output path reused", result.stderr)
                self.assertEqual(before, self.snapshot())

    def test_reserved_and_example_readme_aliases_cannot_be_hub_destinations(self):
        self.write("docs/CATALOG.md", "Existing catalog\n")
        self.write("llms.txt", "Existing index\n")
        aliases = ["%52EADME.md", "docs/%43ATALOG.md", "%6clms.txt", "basics/01-first/%52EADME.md"]
        if sys.platform == "win32":
            aliases += ["readme.md", "docs/catalog.md", "LLMS.TXT", "basics/01-first/readme.md"]
        for alias in aliases:
            with self.subTest(alias=alias):
                self.data["collections"][0]["readme"] = alias
                self.save()
                before = self.snapshot()
                result = self.cli("--validate-only")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Hub output path reused", result.stderr)
                self.assertEqual(before, self.snapshot())

    def test_url_pipes_cannot_split_markdown_cells(self):
        self.data["packages"][0]["url"] = "https://example.org/sdk?a=left|right"
        self.save()
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = (self.root / "docs/CATALOG.md").read_text(encoding="utf-8")
        self.assertIn("https://example.org/sdk?a=left%7Cright", catalog)
        self.assertNotIn("https://example.org/sdk?a=left|right", catalog)

    def test_community_nonnumbered_project_has_separate_review_status(self):
        self.data["categories"].append({"id": "community", "title": "Community", "description": "Projects"})
        self.data["community_subcategories"] = ["tools"]
        self.data["community_status"] = ["community", "verified"]
        example = self.example("community-tool", "community/tools/custom-project", 3)
        example.update(
            category="community",
            subcategory="tools",
            status="verified",
            lifecycle="preview",
            contributor={"name": "A contributor", "github": "https://github.com/example"},
        )
        self.data["examples"].append(example)
        self.write(example["path"] + "/README.md", "# Community\n## Run\n")
        self.save()
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        catalog = (self.root / "docs/CATALOG.md").read_text(encoding="utf-8")
        self.assertIn("Implementation: preview; Community review: verified", catalog)
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "check_community_structure.py"), "--root", str(self.root)],
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1 project", result.stdout)
        del example["status"]
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_root_integration_uses_only_parent_primary_logo_with_providers_listed_first(self):
        self.data["integration_frameworks"][0]["logo"] = {
            "light": "logos/livekit-light.svg",
            "dark": "logos/livekit-dark.svg",
            "height": 24,
        }
        self.data["integration_frameworks"] += [
            {"id": "openai", "title": "OpenAI", "url": "https://example.org/openai", "kind": "service"},
            {
                "id": "twilio",
                "title": "Twilio",
                "url": "https://example.org/twilio",
                "kind": "platform",
                "logo": {"light": "logos/twilio.svg", "dark": "logos/twilio.svg", "height": 24},
            },
        ]
        example = self.data["examples"][1]
        example.update(path="integrations/livekit/02-telephony", integrations=["openai", "twilio", "livekit"])
        before = copy.deepcopy(self.data)
        cell = render_root_table(self.data, "integrations").splitlines()[-1].split("|")[1].strip()
        self.assertEqual(cell.count("<img "), 1)
        self.assertIn('src="logos/livekit-light.svg"', cell)
        self.assertIn('srcset="logos/livekit-dark.svg"', cell)
        self.assertIn('alt="LiveKit"', cell)
        self.assertEqual(re.sub(r"<[^>]+>", "", cell), "")
        self.assertNotIn("<br>", cell)
        self.assertNotIn("Twilio", cell)
        self.assertNotIn("OpenAI", cell)
        self.assertEqual(self.data, before)

    def test_root_primary_integration_name_fallback_unknown_parent_and_direct_api(self):
        self.data["integration_frameworks"].append(
            {"id": "openai", "title": "OpenAI", "url": "https://example.org/openai", "kind": "service"}
        )
        example = self.data["examples"][1]
        cases = [
            ("integrations/livekit/02-telephony", ["openai", "livekit"], "[LiveKit](<integrations/livekit/README.md>)"),
            ("integrations/unknown/01-example", ["openai", "livekit"], "[OpenAI](<https://example.org/openai>)"),
            ("integrations/unknown/01-example", [], "Direct API"),
        ]
        for path, members, expected in cases:
            with self.subTest(path=path, members=members):
                example.update(path=path, integrations=members)
                cell = render_root_table(self.data, "integrations").splitlines()[-1].split("|")[1].strip()
                self.assertEqual(cell, expected)

    def test_root_integrations_group_seed_ids_and_include_cross_category_members(self):
        self.data["integration_frameworks"][0]["description"] = "Build agents & calls | setup choices"
        self.data["integration_frameworks"] += [
            {"id": "openai", "title": "OpenAI", "url": "https://example.org/openai", "kind": "service"},
            {"id": "twilio", "title": "Twilio", "url": "https://example.org/twilio", "kind": "platform"},
        ]
        first, second = self.data["examples"]
        first.update(languages=["typescript"], integrations=["livekit", "openai"])
        second.update(
            path="integrations/livekit/01-bot",
            languages=["python"],
            integrations=["openai", "livekit", "twilio"],
            description="First shared example",
        )
        third = self.example("third", "integrations/livekit/02-bot", 3)
        third.update(category="integrations", languages=["config"], integrations=["livekit"])
        fourth = self.example("fourth", "integrations/twilio/01-dialer", 4)
        fourth.update(category="integrations", integrations=["twilio"])
        fifth = self.example("fifth", "use-cases/01-agent", 5)
        fifth.update(category="use-cases", languages=["config", "typescript"], integrations=["livekit", "twilio"])
        sixth = self.example("sixth", "use-cases/02-provider", 6)
        sixth.update(category="use-cases", integrations=["openai"])
        self.data["examples"] += [third, fourth, fifth, sixth]
        before = copy.deepcopy(self.data)
        lines = render_root_table(self.data, "integrations").splitlines()
        self.assertEqual(lines[0], "| Integration | Examples | What you'll build | Languages |")
        self.assertEqual(len(lines), 4)
        rows = [[cell.strip() for cell in line.split("|")[1:-1]] for line in lines[2:]]
        self.assertEqual(
            rows[0][1:],
            [
                "[4&nbsp;examples](<integrations/livekit/README.md>)",
                "Build agents &amp; calls &#124; setup choices",
                "Python, TypeScript, Configuration",
            ],
        )
        self.assertEqual(
            rows[1][1:],
            [
                "[3&nbsp;examples](<docs/CATALOG.md#integration-twilio>)",
                "First shared example",
                "Python, TypeScript, Configuration",
            ],
        )
        self.assertNotIn("OpenAI", "\n".join(lines))
        self.assertEqual(self.data, before)

    def test_root_single_integration_group_links_canonical_leaf_override(self):
        self.data["integration_frameworks"].append(
            {"id": "twilio", "title": "Twilio", "url": "https://example.org/twilio", "kind": "platform"}
        )
        self.data["examples"][1].update(
            integrations=["twilio"],
            path="integrations/twilio/01-dialer",
            readme="integrations/twilio/01-dialer/guide.md",
        )
        lines = render_root_table(self.data, "integrations").splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn("[1&nbsp;example](<integrations/twilio/01-dialer/guide.md>)", lines[2])
        self.assertNotIn("LiveKit", lines[2])

    def test_root_use_cases_group_all_collections_with_cross_category_counts_and_other(self):
        self.data["collections"] += [
            {"id": "voice-agents", "title": "Voice agents", "description": "Build agents"},
            {"id": "mobile", "title": "Mobile", "description": "Mobile clients"},
            {"id": "unrepresented", "title": "Hidden", "description": "No use-case seed"},
        ]
        first, second = self.data["examples"]
        first.update(collections=["healthcare", "voice-agents", "unrepresented"], languages=["python"])
        second.update(languages=["typescript"])
        third = self.example("third", "use-cases/01-shared", 3)
        third.update(category="use-cases", collections=["healthcare", "voice-agents"], languages=["config"])
        fourth = self.example("fourth", "use-cases/02-health", 4)
        fourth.update(category="use-cases", languages=["python"])
        fifth = self.example("fifth", "use-cases/03-mobile", 5)
        fifth.update(
            category="use-cases",
            collections=["mobile"],
            languages=["typescript"],
            readme="use-cases/03-mobile/guide.md",
        )
        sixth = self.example("sixth", "use-cases/04-other", 6)
        sixth.update(category="use-cases", collections=[], languages=["config"])
        seventh = self.example("seventh", "use-cases/05-other", 7)
        seventh.update(category="use-cases", collections=[], languages=["python"])
        self.data["examples"] += [third, fourth, fifth, sixth, seventh]
        lines = render_root_table(self.data, "use-cases").splitlines()
        self.assertEqual(lines[0], "| Focus | Examples | What you'll build | Languages |")
        rows = [[cell.strip() for cell in line.split("|")[1:-1]] for line in lines[2:]]
        self.assertEqual(
            rows,
            [
                [
                    "Healthcare",
                    "[4&nbsp;examples](<collections/healthcare/README.md>)",
                    "Medical",
                    "Python, TypeScript, Configuration",
                ],
                [
                    "Voice agents",
                    "[2&nbsp;examples](<docs/CATALOG.md#collection-voice-agents>)",
                    "Build agents",
                    "Python, Configuration",
                ],
                ["Mobile", "[1&nbsp;example](<use-cases/03-mobile/guide.md>)", "Mobile clients", "TypeScript"],
                [
                    "Other examples",
                    "[2&nbsp;examples](<docs/CATALOG.md#all-example-details>)",
                    "A pipe &#124; and &lt;script&gt; &amp; useful details.",
                    "Python, Configuration",
                ],
            ],
        )

    def test_integration_registry_accepts_optional_group_description(self):
        self.data["integration_frameworks"][0]["description"] = "Build voice agents with this framework."
        self.save()
        result = self.cli("--validate-only")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_readme_override_is_used_in_every_output_and_missing_override_fails(self):
        self.write("basics/01-first/guide.md", "# Guide\n## Run\n")
        self.data["examples"][0]["readme"] = "basics/01-first/guide.md"
        self.save()
        self.assertEqual(self.cli().returncode, 0)
        for path in ("README.md", "docs/CATALOG.md", "llms.txt", "collections/healthcare/README.md"):
            self.assertIn("basics/01-first/guide.md", (self.root / path).read_text(encoding="utf-8"))
        self.data["examples"][0]["readme"] = "basics/01-first/missing.md"
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_duplicate_registry_and_category_path_mismatch_are_rejected(self):
        self.data["packages"].append(copy.deepcopy(self.data["packages"][0]))
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)
        self.data["packages"].pop()
        self.data["examples"][0]["category"] = "integrations"
        self.save()
        self.assertNotEqual(self.cli("--validate-only").returncode, 0)

    def test_check_does_not_create_bytecode_or_other_files_in_checkout(self):
        for name in ("catalog.py", "generate_catalog.py"):
            target = self.root / ".github/scripts" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SCRIPTS / name, target)
        shutil.copyfile(SCRIPTS.parents[1] / "docs/catalog.schema.yaml", self.root / "docs/catalog.schema.yaml")
        before = self.snapshot()
        result = subprocess.run(
            [sys.executable, str(self.root / ".github/scripts/generate_catalog.py"), "--check"],
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
