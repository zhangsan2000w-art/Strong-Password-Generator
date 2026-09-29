# AI usage

English | [简体中文](AI_USAGE.zh_CN.md)

## Developer-owned direction

The developer defined the product scope, three password modes, parameter bounds and defaults, three-button interaction, offline/privacy requirements, MoonBit-first architecture, target hardware, build artifact, test expectations, documentation set, and the rule that build success must not be presented as device success.

## AI assistance

AI assistance was used to inspect the official repository and hardware contract, investigate the MoonBit native/C FFI path, implement MoonBit and C code, generate the compact word list and CJK font subset, write tests and documentation, and diagnose actual compiler and validation output.

AI-generated or AI-edited code was reviewed through source inspection and executable checks. Compiler errors were handled from their real diagnostics; successful results were not invented. The developer remains responsible for reviewing the code, explaining the design, running physical-device acceptance, and deciding whether to submit or publish a hackathon entry.

## Verification

- MoonBit check runs with warnings denied.
- One hundred thirty-nine deterministic MoonBit tests cover generation policies, boundaries, character classes, output postconditions, passphrase formatting, dictionary indexes, rejection sampling, transitions, input gestures, result lifecycle, view models, battery policy, strength classification, sound waveforms, and the FAP_SCREENSHOT_V1 command matcher, reply header builder, snapshot geometry check, band-ordering state machine, frame accounting, and fault vocabulary. They run as 12 portable-library tests, 3 CLI tests, 2 browser-command tests, 2 separate-module consumer tests, and 120 firmware-adapter tests. Twenty-five Python host tests cover the screenshot tool's header parsing, RGB565 conversion, and PNG writer, the firmware layout verifier, and the compiler-version gate.
- After the entry was rejected for having fewer than 1,000 MoonBit lines, AI assistance helped migrate independently testable product policy from C to MoonBit. The current tree measures 3,821 effective production MoonBit lines (775 in the root library plus 3,046 in the firmware adapter) and 2,202 effective test lines counted by the same rule; `python tools/check_repo.py` prints the production figure and the production gate requires at least 1,000.
- ESP-IDF 5.5.3 compiles generated MoonBit C into the ESP32-C3 application. The serial screenshot rides the panel `draw_bitmap` tap in 240x20 bands; `CONFIG_LV_USE_SNAPSHOT` is no longer required by that path and is retained only until it is removed.
- The merged image verifier checks bootloader, partition table, application offsets, partition fit, and the complete `-full.bin` image.
- The band-stream build (`46a370e`) was flashed to a physical AI Passport and booted to `Ready: secure_random=1 buttons=1 ble_keyboard=1`, advertising as `FoloPassKey`. Captured panel frames render the CJK subset and the credential screen correctly, band boundaries show no seams, and repeated `FAP_SCREENSHOT_V1` captures succeeded while the keyboard stayed advertising. Writing the merged image at `0x0` reset NVS, so settings loaded from defaults. Still unverified on hardware: pairing with a real host, HID typing, the three button gestures, the Settings screen, preference persistence across reboot, the sound toggle, and battery behaviour over time. An earlier image had reported thin CJK strokes and 77% or 0% fuel-gauge readings; neither observation was re-tested in this run. The pairing watchdog and the label-glyph subset that sit on top of that build are covered by host tests and a clean firmware build only; the device was disconnected before the newer image could be flashed.

## Human review checklist

Before hackathon submission, the developer should inspect the RNG initialization order and failure behavior, read the state-machine tests, confirm every UI string on hardware, verify the three-button flows, review third-party notices, and reproduce both validation commands from a clean checkout.
