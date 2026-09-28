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

- `moonbit/screenshot.mbt` owns the protocol core and the capture session, and
  is covered by `moon test`: the command matcher (a state machine equivalent to
  the sliding-window matcher with line-terminator reset), the reply header
  builder, the band state machine that validates every strip the panel emits
  (ordering, full-width tiling, tight packing, panel bounds), the frame
  accounting that decides when a capture is complete, the fault vocabulary, and
  the band byte-order policy. The C adapter only passes integers, reports
  events, and receives bytes through `passport_screenshot_header_*` and
  `passport_screenshot_name_*` callbacks.
- `main/fap_screenshot.c` owns the platform boundary and nothing else: explicit
  USB-Serial-JTAG driver installation (256-byte RX, 1024-byte TX), a
  priority-3 reader task below the LVGL task, the panel `draw_bitmap` tap, a
  two-slot band ring, 512-byte chunked streaming sized to the TX ring buffer,
  the LVGL lock discipline around arming, and log muting during the binary
  window.

Why the completion rule lives in MoonBit: the tap (producer, LVGL task) and the
serial writer (consumer) advance two separate counters, and with a two-slot ring
the tap runs ahead of the writer. Declaring the frame finished from "bytes
produced" returns success while the last strip is still unsent, silently
truncating the image. That rule is pinned by a host test instead.

Why bands instead of one frame buffer: this board has no PSRAM, and its
internal RAM is split into a 118,848-byte general heap region and a separate
116,496-byte retention region. A single allocation cannot span regions, so a
153,600-byte full-frame buffer is unreachable no matter how much memory is
free — measured after suspending the BLE stack, free internal heap was
183,652 bytes but the largest contiguous block was only 106,496. The BLE
keyboard also needs roughly 115 KB, so "one full frame" and "BLE online" are
arithmetically exclusive. The capture therefore rides the LVGL partial
refresh: the display driver already holds one 240x20 strip in memory at flush
time, so the panel tap copies each strip (converting back from the big-endian
order `esp_lvgl_port` applies for the SPI panel) into an 18.75 KB ring that is
allocated for the duration of the capture and freed right after. The host
sees the same byte stream as before, and the BLE stack is never suspended.
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
- Arming a capture forces a full-screen invalidation, so the panel visibly
  repaints while it is being read, and the LVGL task blocks inside the tap
  whenever the host drains slower than the device produces. The picture is
  therefore a consistent single frame, not a live overlay, and a slow or
  disconnected host ends the capture with a fault rather than a stall.
