#!/usr/bin/env python3
"""Tests for the MoonBit compiler acceptance-version gate."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_moonc_version", ROOT / "tools" / "check_moonc_version.py"
)
assert SPEC and SPEC.loader
VERSION = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = VERSION
SPEC.loader.exec_module(VERSION)


class MooncVersionTest(unittest.TestCase):
    def test_parses_release_and_build_metadata(self) -> None:
        self.assertEqual(VERSION.parse_version("moonc v0.10.14"), (0, 10, 14))
        self.assertEqual(
            VERSION.parse_version("moonc v0.10.14+1634b282e (2026-09-21)"),
            (0, 10, 14),
        )

    def test_enforces_minimum_without_lexicographic_comparison(self) -> None:
        self.assertFalse(VERSION.is_supported((0, 10, 12)))
        self.assertTrue(VERSION.is_supported((0, 10, 14)))
        self.assertTrue(VERSION.is_supported((0, 11, 0)))

    def test_rejects_unrecognized_output(self) -> None:
        with self.assertRaisesRegex(ValueError, "cannot parse"):
            VERSION.parse_version("MoonBit compiler version unavailable")


if __name__ == "__main__":
    unittest.main()
