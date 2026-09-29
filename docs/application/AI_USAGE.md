# AI usage

English | [简体中文](AI_USAGE.zh_CN.md)

## Developer-owned direction

The developer defined the product scope, three password modes, parameter bounds and defaults, three-button interaction, offline/privacy requirements, MoonBit-first architecture, target hardware, build artifact, test expectations, documentation set, and the rule that build success must not be presented as device success.

## AI assistance

AI assistance was used to inspect the official repository and hardware contract, investigate the MoonBit native/C FFI path, implement MoonBit and C code, generate the compact word list and CJK font subset, write tests and documentation, and diagnose actual compiler and validation output.

AI-generated or AI-edited code was reviewed through source inspection and executable checks. Compiler errors were handled from their real diagnostics; successful results were not invented. The developer remains responsible for reviewing the code, explaining the design, running physical-device acceptance, and deciding whether to submit or publish a hackathon entry.

## Verification

- MoonBit check runs with warnings denied.
- One hundred twenty-two deterministic MoonBit tests cover generation policies, boundaries, character classes, output postconditions, passphrase formatting, dictionary indexes, rejection sampling, transitions, input gestures, result lifecycle, view models, battery policy, strength classification, sound waveforms, and the FAP_SCREENSHOT_V1 command matcher, reply header builder, and snapshot geometry check. They run as 12 portable-library tests, 3 CLI tests, 2 browser-command tests, 2 separate-module consumer tests, and 103 firmware-adapter tests. Twenty-one Python host tests cover the screenshot tool's header parsing, RGB565 conversion, and PNG writer, the firmware layout verifier, and the compiler-version gate.
- After the entry was rejected for having fewer than 1,000 MoonBit lines, AI assistance helped migrate independently testable product policy from C to MoonBit. The tree at release commit `8b4e466` measures 3,632 effective production MoonBit lines (775 in the root library plus 2,857 in the firmware adapter) and 2,010 effective test lines counted by the same rule; `python tools/check_repo.py` prints the production figure and the production gate requires at least 1,000.
- ESP-IDF 5.5.3 compiles generated MoonBit C into the ESP32-C3 application. `CONFIG_LV_USE_SNAPSHOT` is enabled for the serial screenshot.
- The merged image verifier checks bootloader, partition table, application offsets, partition fit, and the complete `-full.bin` image.
- An earlier image was flashed to a real AI Passport and confirmed layout and PIN output. The user later confirmed that compressed CJK text rendered but reported thin strokes. The first battery-profile change passed the initial boot display but later showed 77%, or 0% on an unplugged boot. The heavier font, no-reset fuel-gauge behavior, and success chime still require a fresh device run.

## Human review checklist

Before hackathon submission, the developer should inspect the RNG initialization order and failure behavior, read the state-machine tests, confirm every UI string on hardware, verify the three-button flows, review third-party notices, and reproduce both validation commands from a clean checkout.
