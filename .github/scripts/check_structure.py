#!/usr/bin/env python3
"""
Speechmatics Academy — Structure & Catalog Validator

Validates that docs/index.yaml stays in sync with the actual examples on disk.
Checks:
  1. Every cataloged example path exists
  2. Every example has a README.md
  3. Every example has a .env.example
  4. Python examples have requirements.txt (in python/ subdir or project root)
  5. total_examples count matches actual entries
  6. Orphaned example directories not in catalog
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
INDEX_FILE = REPO_ROOT / "docs" / "index.yaml"

# Categories that contain numbered example directories
EXAMPLE_CATEGORIES = ["basics", "integrations", "use-cases", "community"]

# Known non-example directories at the integration level (contain sub-projects)
INTEGRATION_PARENTS = {"livekit", "pipecat", "twilio", "vapi", "tambourine", "vercel"}

# Community subcategories (act like integration parents — contain project directories)
COMMUNITY_SUBCATEGORIES = {"use-cases", "integrations", "tools", "experiments"}


def parse_index_yaml(path: Path) -> tuple[list[dict], int]:
    """Parse index.yaml using regex (stdlib only, no PyYAML dependency).

    Returns (list of example dicts with 'id' and 'path', declared total_examples).
    """
    text = path.read_text(encoding="utf-8")

    # Extract total_examples
    total_match = re.search(r"^total_examples:\s*(\d+)", text, re.MULTILINE)
    total_examples = int(total_match.group(1)) if total_match else -1

    # Extract example blocks — each starts with "- id:" under the examples: section
    examples = []
    examples_match = re.search(r"^examples:\s*$", text, re.MULTILINE)
    examples_section = text[examples_match.end() :] if examples_match else ""

    # Find all id + path pairs
    blocks = re.split(r"\n\s*- id:", examples_section)
    for block in blocks[1:]:  # skip first empty split
        id_match = re.match(r'\s*"([^"]+)"', block)
        path_match = re.search(r'path:\s*"([^"]+)"', block)
        languages_match = re.search(r"languages:\s*\[([^\]]+)\]", block)

        if id_match and path_match:
            languages = []
            if languages_match:
                languages = [lang.strip().strip('"') for lang in languages_match.group(1).split(",")]
            examples.append(
                {
                    "id": id_match.group(1),
                    "path": path_match.group(1),
                    "languages": languages,
                }
            )

    return examples, total_examples


def find_example_dirs_on_disk() -> set[str]:
    """Discover example directories on disk by convention.

    Examples live under basics/NN-name/, integrations/framework/NN-name/,
    and use-cases/NN-name/.
    """
    found = set()
    numbered_dir = re.compile(r"^\d{2}-")

    for category in EXAMPLE_CATEGORIES:
        category_path = REPO_ROOT / category
        if not category_path.is_dir():
            continue

        for child in sorted(category_path.iterdir()):
            if not child.is_dir():
                continue

            if category == "integrations":
                # integrations have a framework-level parent directory
                if child.name in INTEGRATION_PARENTS:
                    for sub in sorted(child.iterdir()):
                        if sub.is_dir() and numbered_dir.match(sub.name):
                            rel = sub.relative_to(REPO_ROOT).as_posix()
                            found.add(rel)
            elif category == "community":
                # community has subcategory parent directories (no numbered prefixes)
                if child.name in COMMUNITY_SUBCATEGORIES:
                    for sub in sorted(child.iterdir()):
                        if sub.is_dir():
                            rel = sub.relative_to(REPO_ROOT).as_posix()
                            found.add(rel)
            else:
                if numbered_dir.match(child.name):
                    rel = child.relative_to(REPO_ROOT).as_posix()
                    found.add(rel)

    return found


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    if not INDEX_FILE.exists():
        print(f"FATAL: {INDEX_FILE} not found")
        return 1

    examples, declared_total = parse_index_yaml(INDEX_FILE)

    # --- Check 1: total_examples count ---
    actual_count = len(examples)
    if declared_total != actual_count:
        errors.append(
            f"total_examples mismatch: declared {declared_total}, but found {actual_count} entries in catalog"
        )

    cataloged_paths = set()

    for ex in examples:
        ex_path = REPO_ROOT / ex["path"]
        cataloged_paths.add(ex["path"])

        # --- Check 2: example path exists ---
        if not ex_path.is_dir():
            errors.append(f"[{ex['id']}] path does not exist: {ex['path']}")
            continue

        # --- Check 3: README.md exists ---
        if not (ex_path / "README.md").is_file():
            errors.append(f"[{ex['id']}] missing README.md in {ex['path']}")

        # --- Check 4: .env.example exists ---
        if not (ex_path / ".env.example").is_file():
            warnings.append(f"[{ex['id']}] missing .env.example in {ex['path']}")

        # --- Check 5: Python requirements.txt ---
        if "python" in ex.get("languages", []):
            has_requirements = (ex_path / "python" / "requirements.txt").is_file() or (
                ex_path / "requirements.txt"
            ).is_file()
            has_pyproject = (ex_path / "pyproject.toml").is_file()
            if not has_requirements and not has_pyproject:
                warnings.append(f"[{ex['id']}] no requirements.txt or pyproject.toml found in {ex['path']}")

    # --- Check 6: orphaned directories ---
    disk_paths = find_example_dirs_on_disk()
    orphaned = disk_paths - cataloged_paths
    for orphan in sorted(orphaned):
        warnings.append(f"Orphaned example directory not in catalog: {orphan}")

    # --- Report ---
    if warnings:
        print(f"\n{'=' * 60}")
        print(f"  WARNINGS ({len(warnings)})")
        print(f"{'=' * 60}")
        for w in warnings:
            print(f"  WARNING: {w}")

    if errors:
        print(f"\n{'=' * 60}")
        print(f"  ERRORS ({len(errors)})")
        print(f"{'=' * 60}")
        for e in errors:
            print(f"  ERROR: {e}")
        print()
        print(f"Structure check FAILED with {len(errors)} error(s)")
        return 1

    print(f"\nStructure check PASSED - {actual_count} examples validated")
    if warnings:
        print(f"  ({len(warnings)} warning(s) — see above)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
