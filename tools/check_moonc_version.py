#!/usr/bin/env python3
"""Reject MoonBit compilers older than the competition baseline."""

from __future__ import annotations

import re
import subprocess
import sys


MINIMUM_VERSION = (0, 10, 14)
VERSION_RE = re.compile(r"\bv?(\d+)\.(\d+)\.(\d+)(?:[+-][0-9A-Za-z.-]+)?\b")


def parse_version(text: str) -> tuple[int, int, int]:
    """Extract the first semantic compiler version from `moonc -v` output."""
    match = VERSION_RE.search(text)
    if match is None:
        raise ValueError(f"cannot parse moonc version from: {text.strip()!r}")
    return tuple(int(part) for part in match.groups())


def is_supported(version: tuple[int, int, int]) -> bool:
    """Return whether a compiler version satisfies the acceptance baseline."""
    return version >= MINIMUM_VERSION


def main() -> int:
    try:
        result = subprocess.run(
            ["moonc", "-v"],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print("ERROR: moonc is not available on PATH.", file=sys.stderr)
        return 1

    output = "\n".join(part for part in (result.stdout, result.stderr) if part)
    try:
        version = parse_version(output)
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    rendered = ".".join(str(part) for part in version)
    minimum = ".".join(str(part) for part in MINIMUM_VERSION)
    if not is_supported(version):
        print(
            f"ERROR: moonc {rendered} is too old; moonc {minimum} or newer is required.",
            file=sys.stderr,
        )
        return 1

    print(f"MoonBit compiler: PASS (moonc {rendered}, minimum {minimum})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
