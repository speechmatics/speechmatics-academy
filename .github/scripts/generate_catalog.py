#!/usr/bin/env python3
"""Validate metadata and regenerate catalog navigation without calling any API."""

import argparse
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from catalog import REPO_ROOT, CatalogError, load_catalog, prepare_outputs, update_outputs


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="Repository root (defaults to this checkout)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Fail on stale outputs; never write files")
    mode.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate metadata and local references without checking generated freshness",
    )
    args = parser.parse_args(argv)
    try:
        data = load_catalog(args.root)
        if args.validate_only:
            print(f"Catalog valid: {len(data['examples'])} examples")
            return 0
        outputs = prepare_outputs(data, args.root)
        changed = update_outputs(args.root, outputs, check=args.check)
        print(
            f"Catalog {'fresh' if args.check else 'generated'}: {len(data['examples'])} examples; {len(changed)} files updated"
        )
        return 0
    except (CatalogError, OSError) as error:
        print(f"Catalog error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
