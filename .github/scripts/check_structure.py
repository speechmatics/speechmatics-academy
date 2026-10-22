#!/usr/bin/env python3
"""Compatibility entrypoint for shared YAML/schema/path catalog validation."""

import sys

sys.dont_write_bytecode = True

from generate_catalog import main

if __name__ == "__main__":
    sys.exit(main(["--validate-only", *sys.argv[1:]]))
