#!/usr/bin/env python3
"""Capture a FoloToy AI Passport screen over the FAP_SCREENSHOT_V1 serial protocol.

The firmware listens on USB-CDC for the ASCII command ``FAP_SCREENSHOT_V1\\n``
and answers with a header line followed by a tight-packed little-endian RGB565
frame (protocol notes: docs/reference/y2lin/serial-screenshot-protocol.md).

Examples:
    python tools/screenshot.py --list-ports
    python tools/screenshot.py --port COM5 --output screen.png
    python tools/screenshot.py --raw dump.bin --width 240 --height 320 --output screen.png

Only the raw-conversion path is dependency-free; serial capture needs pyserial
(``pip install pyserial``).
"""

from __future__ import annotations

import argparse
import binascii
import struct
import sys
import time
import zlib
from pathlib import Path

COMMAND = b"FAP_SCREENSHOT_V1\n"
PIXEL_FORMAT = "RGB565LE"
DEFAULT_WIDTH = 240
DEFAULT_HEIGHT = 320


def parse_header(line: bytes) -> tuple[int, int, int]:
    """Parse ``FAP_SCREENSHOT_V1 <w> <h> RGB565LE <bytes>\\n``; raise ValueError."""
    text = line.decode("ascii", errors="strict").strip()
    parts = text.split()
    if len(parts) != 5 or parts[0] != "FAP_SCREENSHOT_V1":
        raise ValueError(f"unexpected header: {text!r}")
    if parts[3] != PIXEL_FORMAT:
        raise ValueError(f"unsupported pixel format: {parts[3]!r}")
    width, height, size = int(parts[1]), int(parts[2]), int(parts[4])
    if width <= 0 or height <= 0:
        raise ValueError(f"bad dimensions: {width}x{height}")
    if size != width * height * 2:
        raise ValueError(
            f"declared size {size} does not match {width}x{height} RGB565"
        )
    return width, height, size


def rgb565le_to_rows(data: bytes, width: int, height: int) -> bytes:
    """Convert tight-packed little-endian RGB565 into RGB888 rows."""
    expected = width * height * 2
    if len(data) != expected:
        raise ValueError(f"expected {expected} pixel bytes, got {len(data)}")
    out = bytearray()
    for index in range(0, len(data), 2):
        value = data[index] | (data[index + 1] << 8)
        r5 = (value >> 11) & 0x1F
        g6 = (value >> 5) & 0x3F
        b5 = value & 0x1F
        out += bytes(
            (
                (r5 << 3) | (r5 >> 2),
                (g6 << 2) | (g6 >> 4),
                (b5 << 3) | (b5 >> 2),
            )
        )
    return bytes(out)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    """Write an 8-bit RGB PNG with the standard library only."""

    def chunk(tag: bytes, payload: bytes) -> bytes:
        body = tag + payload
        return (
            struct.pack(">I", len(payload))
            + body
            + struct.pack(">I", binascii.crc32(body) & 0xFFFFFFFF)
        )

    stride = width * 3
    raw = b"".join(b"\x00" + rgb[y * stride : (y + 1) * stride] for y in range(height))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def read_exact(serial, size: int, deadline: float) -> bytes:
    """Read exactly ``size`` bytes or raise when the deadline passes."""
    data = bytearray()
    while len(data) < size and time.monotonic() < deadline:
        chunk = serial.read(size - len(data))
        if chunk:
            data += chunk
        else:
            time.sleep(0.01)
    if len(data) != size:
        raise TimeoutError(f"payload ended early: {len(data)}/{size} bytes")
    return bytes(data)


def capture(port: str, baud: int, output: Path, timeout: float) -> tuple[int, int]:
    import serial  # pyserial, imported lazily so raw mode stays dependency-free

    with serial.Serial(port, baud, timeout=0.5) as device:
        device.reset_input_buffer()
        device.write(COMMAND)
        device.flush()
        deadline = time.monotonic() + timeout
        # Skip stray log lines: the device may emit firmware logs around the
        # capture window; resync on the first line that parses as a header.
        width = height = size = None
        while time.monotonic() < deadline:
            line = device.readline()
            if not line:
                continue
            try:
                width, height, size = parse_header(line)
                break
            except ValueError:
                continue
        if width is None:
            raise TimeoutError("device did not answer (check the port / firmware)")
        payload = read_exact(device, size, deadline)
    rows = rgb565le_to_rows(payload, width, height)
    write_png(output, width, height, rows)
    return width, height


def list_ports() -> None:
    try:
        from serial.tools import list_ports
    except ImportError:
        sys.exit("pyserial is required for --list-ports (pip install pyserial)")
    for entry in list_ports.comports():
        print(f"{entry.device}\t{entry.description}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", help="serial port of the device, e.g. COM5")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--output", type=Path, default=Path("screenshot.png"))
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument(
        "--raw",
        type=Path,
        help="convert an existing RGB565LE dump instead of capturing",
    )
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH)
    parser.add_argument("--height", type=int, default=DEFAULT_HEIGHT)
    parser.add_argument("--list-ports", action="store_true")
    args = parser.parse_args(argv)

    if args.list_ports:
        list_ports()
        return 0

    if args.raw:
        payload = args.raw.read_bytes()
        width, height, size = args.width, args.height, args.width * args.height * 2
        if len(payload) < size:
            raise SystemExit(
                f"{args.raw} holds {len(payload)} bytes; "
                f"{width}x{height} RGB565 needs {size}"
            )
        rows = rgb565le_to_rows(payload[:size], width, height)
        write_png(args.output, width, height, rows)
        print(f"saved {args.output} ({width}x{height}, from {args.raw})")
        return 0

    if not args.port:
        parser.error("--port is required (or use --list-ports / --raw)")

    width, height = capture(args.port, args.baud, args.output, args.timeout)
    print(f"saved {args.output} ({width}x{height}, captured from {args.port})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
