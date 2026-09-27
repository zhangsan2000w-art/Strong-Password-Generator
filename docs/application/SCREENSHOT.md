# FAP_SCREENSHOT_V1 serial screenshot

English | [简体中文](SCREENSHOT.zh_CN.md)

`FAP_SCREENSHOT_V1` is an observational serial protocol for capturing the
device screen from a computer. The host sends one ASCII command over USB-CDC
and the firmware replies with a header line plus a tight-packed little-endian
RGB565 frame. The command never reboots, flashes, or changes any setting; on
any failure the device stays silent and the host reports a timeout.

The implementation follows the pitfalls recorded in
[`docs/reference/y2lin/serial-screenshot-protocol.md`](../reference/y2lin/serial-screenshot-protocol.md).

## Usage from a computer

```bash
python tools/screenshot.py --list-ports
python tools/screenshot.py --port COM5 --output screen.png
# Convert an existing RGB565LE dump without a device:
python tools/screenshot.py --raw dump.bin --width 240 --height 320 --output screen.png
```

Serial capture needs `pyserial`; raw conversion is standard-library only. The
tool writes an 8-bit RGB PNG. The device must be running the app firmware with
this feature (USB cable plugged in; the port enumerates as a USB serial/JTAG
device).

## Protocol

```text
host  -> device: "FAP_SCREENSHOT_V1\n"            (ASCII, sliding-window match)
device -> host:  "FAP_SCREENSHOT_V1 <w> <h> RGB565LE <bytes>\n"
device -> host:  <bytes> little-endian RGB565 pixels, tight-packed, row-major
```

On this board the reply is always `FAP_SCREENSHOT_V1 240 320 RGB565LE 153600\n`
followed by 153,600 pixel bytes.

## Architecture split

- `moonbit/screenshot.mbt` owns the protocol core and is covered by
  `moon test`: the command matcher (a state machine equivalent to the
  sliding-window matcher with line-terminator reset), the reply header
  builder, and the snapshot geometry check. The C adapter only passes
  integers and receives bytes through two `passport_screenshot_header_*`
  callbacks.
- `main/fap_screenshot.c` owns the platform boundary: explicit
  USB-Serial-JTAG driver installation (256-byte RX, 1024-byte TX), a
  priority-3 reader task below the LVGL task, the static 64-byte-aligned
  full-screen snapshot buffer rendered with `lv_snapshot_take_to_draw_buf()`
  under `bsp_lvgl_lock()`, 512-byte chunked streaming sized to the TX ring
  buffer, and log muting during the binary window.
- `tools/screenshot.py` is the host-side capture/convert tool; its pure
  helpers are covered by `tests/test_screenshot_convert.py`.

## Boundaries

- The capture is read-only and observational. It does not interact with the
  password application state and cannot trigger BLE, audio, or storage.
- Log output and the binary reply share one USB-CDC stream; the firmware
  silences logging for the duration of the reply window, so screenshot bytes
  are only reliable through a protocol client (not a plain terminal dump).
- Battery level, themes, and screen content are captured as displayed; there
  is no synthetic or off-screen rendering.
