# FoloToy AI Passport adapter example

English | [简体中文](README.zh_CN.md)

This directory is a real ESP32-C3 application that consumes the repository's
root `zhangsan2000w-art/moonbit-securegen` library. It demonstrates how an
embedded adapter can inject hardware randomness and connect generated values to
FoloToy display, input, audio, persistence, and BLE HID services.

The reusable library does not depend on anything in this directory. ESP-IDF,
LVGL, NimBLE, NVS, C FFI declarations, the Flash word-list adapter, and the
vendored MoonBit runtime remain behind this application boundary.

## Build

From the repository root, activate ESP-IDF 5.5.3 and run:

```bash
./tools/validate.sh --firmware
```

For an incremental build from this directory:

```bash
idf.py set-target esp32c3
idf.py build
```

A successful build is not hardware acceptance. BLE pairing, reconnect, bond
persistence, exact HID typing, buttons, display, audio, NVS, battery readings,
and the hardware RNG adapter still require on-device verification.
