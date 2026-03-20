#!/usr/bin/env python3
"""
Speechmatics Academy — Community Project Structure Validator

Lightweight validator for community-contributed projects.
Checks:
  1. Every community project has a README.md
  2. Every community project has a CONTRIBUTORS.md (warning if missing)
  3. Every community project has a .env.example (warning if missing)
  4. Every community project on disk has an entry in index.yaml with category: "community"
  5. No hardcoded API key patterns in source files
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
COMMUNITY_DIR = REPO_ROOT / "community"
INDEX_FILE = REPO_ROOT / "docs" / "index.yaml"

COMMUNITY_SUBCATEGORIES = {"use-cases", "integrations", "tools", "experiments"}

# Patterns that suggest hardcoded secrets
SECRET_PATTERNS = [
    re.compile(r"sk-[a-zA-Z0-9]{20,}"),
    re.compile(r"SPEECHMATICS_API_KEY\s*=\s*['\"]sm_[a-zA-Z0-9]+['\"]"),
]

SOURCE_EXTENSIONS = {".py", ".ts", ".js", ".go", ".rs", ".cs"}


def find_community_projects() -> set[str]:
    """Discover community project directories on disk."""
    found = set()

    if not COMMUNITY_DIR.is_dir():
        return found

    for subcategory in sorted(COMMUNITY_DIR.iterdir()):
        if not subcategory.is_dir():
            continue
        if subcategory.name not in COMMUNITY_SUBCATEGORIES:
            continue
        for project in sorted(subcategory.iterdir()):
            if project.is_dir():
                rel = project.relative_to(REPO_ROOT).as_posix()
                found.add(rel)

    return found


def parse_community_paths_from_index() -> set[str]:
    """Extract paths of community examples from index.yaml."""
    if not INDEX_FILE.exists():
        return set()

    text = INDEX_FILE.read_text(encoding="utf-8")
    paths = set()

    # Find blocks with category: "community" and extract their paths
    examples_match = re.search(r"^examples:\s*$", text, re.MULTILINE)
    if not examples_match:
        return paths

    examples_section = text[examples_match.end() :]
    blocks = re.split(r"\n\s*- id:", examples_section)

    for block in blocks[1:]:
        category_match = re.search(r'category:\s*"community"', block)
        if category_match:
            path_match = re.search(r'path:\s*"([^"]+)"', block)
            if path_match:
                paths.add(path_match.group(1))

    return paths


def check_secrets(project_path: Path) -> list[str]:
    """Scan source files for hardcoded secret patterns."""
    findings = []
    for file in project_path.rglob("*"):
        if file.suffix not in SOURCE_EXTENSIONS:
            continue
        if "venv" in file.parts or ".venv" in file.parts or "node_modules" in file.parts:
            continue
        try:
            content = file.read_text(encoding="utf-8", errors="ignore")
            for pattern in SECRET_PATTERNS:
                matches = pattern.findall(content)
                if matches:
                    rel = file.relative_to(REPO_ROOT).as_posix()
                    findings.append(f"Potential secret in {rel}: {matches[0][:20]}...")
        except Exception:
            pass
    return findings


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    if not COMMUNITY_DIR.is_dir():
        print("No community/ directory found — skipping community checks")
        return 0

    disk_projects = find_community_projects()
    catalog_paths = parse_community_paths_from_index()

    if not disk_projects:
        print("No community projects found on disk — nothing to validate")
        return 0

    for project_rel in sorted(disk_projects):
        project_path = REPO_ROOT / project_rel
        project_name = project_path.name

        # Check 1: README.md exists (required)
        if not (project_path / "README.md").is_file():
            errors.append(f"[{project_name}] missing README.md in {project_rel}")

        # Check 2: CONTRIBUTORS.md exists (warning)
        if not (project_path / "CONTRIBUTORS.md").is_file():
            warnings.append(f"[{project_name}] missing CONTRIBUTORS.md in {project_rel}")

        # Check 3: .env.example exists (warning)
        if not (project_path / ".env.example").is_file():
            warnings.append(f"[{project_name}] missing .env.example in {project_rel}")

        # Check 4: catalog entry exists (required)
        if project_rel not in catalog_paths:
            errors.append(f"[{project_name}] not found in index.yaml catalog: {project_rel}")

        # Check 5: no hardcoded secrets (required)
        secret_findings = check_secrets(project_path)
        for finding in secret_findings:
            errors.append(f"[{project_name}] {finding}")

    # Check for catalog entries with no matching disk directory
    orphaned_catalog = catalog_paths - disk_projects
    for orphan in sorted(orphaned_catalog):
        errors.append(f"Catalog entry has no matching directory: {orphan}")

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
        print(f"Community structure check FAILED with {len(errors)} error(s)")
        return 1

    print(f"\nCommunity structure check PASSED - {len(disk_projects)} project(s) validated")
    if warnings:
        print(f"  ({len(warnings)} warning(s) — see above)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
