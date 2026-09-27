#!/usr/bin/env python3
"""Host tests for the FAP_SCREENSHOT_V1 host tool's pure helpers."""

from __future__ import annotations

import importlib.util
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "screenshot_tool", ROOT / "tools" / "screenshot.py"
)
assert SPEC and SPEC.loader
TOOL = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = TOOL
SPEC.loader.exec_module(TOOL)


class HeaderTests(unittest.TestCase):
    def test_parses_documented_header(self) -> None:
        self.assertEqual(
            TOOL.parse_header(b"FAP_SCREENSHOT_V1 240 320 RGB565LE 153600\n"),
            (240, 320, 153600),
        )

    def test_rejects_unknown_format(self) -> None:
        with self.assertRaises(ValueError):
            TOOL.parse_header(b"FAP_SCREENSHOT_V1 240 320 RGB888 153600\n")

    def test_rejects_size_mismatch(self) -> None:
        with self.assertRaises(ValueError):
            TOOL.parse_header(b"FAP_SCREENSHOT_V1 240 320 RGB565LE 100\n")

    def test_rejects_garbage(self) -> None:
        with self.assertRaises(ValueError):
            TOOL.parse_header(b"hello world\n")


class ConversionTests(unittest.TestCase):
    def test_primary_colors(self) -> None:
        red = bytes((0x00, 0xF8))
        green = bytes((0xE0, 0x07))
        blue = bytes((0x1F, 0x00))
        white = bytes((0xFF, 0xFF))
        data = red + green + blue + white
        self.assertEqual(
            TOOL.rgb565le_to_rows(data, 4, 1),
            b"\xff\x00\x00" b"\x00\xff\x00" b"\x00\x00\xff" b"\xff\xff\xff",
        )

    def test_rejects_truncated_payload(self) -> None:
        with self.assertRaises(ValueError):
            TOOL.rgb565le_to_rows(b"\x00\xF8", 4, 1)


class PngTests(unittest.TestCase):
    def test_writes_valid_rgb_png(self) -> None:
        width, height = 2, 2
        rgb = bytes(range(width * height * 3))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "shot.png"
            TOOL.write_png(path, width, height, rgb)
            blob = path.read_bytes()
        self.assertTrue(blob.startswith(b"\x89PNG\r\n\x1a\n"))
        ihdr = blob[blob.index(b"IHDR") - 4 : blob.index(b"IHDR") + 4 + 13]
        (ihdr_size,) = struct.unpack(">I", ihdr[:4])
        self.assertEqual(ihdr_size, 13)
        parsed_width, parsed_height = struct.unpack(">II", ihdr[8:16])
        self.assertEqual((parsed_width, parsed_height), (width, height))
        start = blob.index(b"IDAT") + 4
        (idat_size,) = struct.unpack(">I", blob[start - 8 : start - 4])
        raw = zlib.decompress(blob[start : start + idat_size])
        self.assertEqual(len(raw), height * (1 + width * 3))
        self.assertEqual(raw[:: 1 + width * 3], b"\x00" * height)


if __name__ == "__main__":
    unittest.main()
