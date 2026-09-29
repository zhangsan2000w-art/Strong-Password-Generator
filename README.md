# SecureGen for MoonBit

English | [简体中文](README.zh_CN.md)

**SecureGen** is a reusable MoonBit credential-generation engine with typed
policies, caller-injected entropy, portable application APIs, and
allocation-controlled embedded APIs. This repository includes independent CLI,
browser, external-module, and FoloToy firmware consumers.

The firmware is a reference application of the MoonBit package, not the package
boundary itself. Consumers can import `zhangsan2000w-art/moonbit-securegen`
without ESP-IDF,
FoloToy, LVGL, BLE, a filesystem, or network access.

For a short evaluation path, see the
[reviewer guide](docs/competition/REVIEW_GUIDE.md), then run:

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon run src/cmd/securegen --target js --release -- --profile strict --length 24
```

## Install and use

Use MoonBit with `moonc` 0.10.14 or newer. Add the published module to a new or
existing MoonBit project:

```bash
moon add zhangsan2000w-art/moonbit-securegen
```

Import the root package from the consumer's `moon.pkg`:

```moonbit
import {
  "zhangsan2000w-art/moonbit-securegen" @securegen,
}
```

Then inject the cryptographically secure random source supplied by the target
platform:

```moonbit
let policy = @securegen.PasswordPolicy::standard()
match @securegen.generate_password(policy, secure_random_u32) {
  Ok(password) => println(password)
  Err(message) => println("generation failed: \{message}")
}
```

The complete separate-module example is in
[`examples/consumer`](examples/consumer/README.md). The CLI and browser example
provide immediately runnable application paths.

## FoloToy reference application

The firmware starts directly in the generator. It does not connect to a network, store password history, or redefine the system power button. A generated value leaves the device only after the user explicitly selects **Send**, through the paired encrypted BLE HID keyboard connection.

The embedded application is an offline three-button password generator built
for FoloToy AI Passport. It starts directly in the generator, does not connect
to a network or store password history, and sends a generated value only after
the user explicitly selects **Send** over an encrypted BLE HID connection.

### Firmware features

- **Random**: 6–30 printable ASCII characters, default length 10, letters always enabled, optional digits and symbols. Every enabled optional class is guaranteed to appear.
- **Memorable**: 3–6 offline words, default 4, optional capitalization, complete or four-character abbreviated words, and `-`, `.`, or `_` separators.
- **PIN**: 4–12 decimal digits, default length 6.
- **Input**: `UP`, `DOWN`, and `OK` only. `OK` enters or confirms editing, toggles Boolean values, or generates. Holding `UP` / `DOWN` continuously changes a numeric value while editing. Long-pressing `OK` cancels an edit; outside editing it switches the theme. Long-pressing `DOWN` outside editing opens Settings.
- **Feedback**: MoonBit generates the success chime's frequencies, durations, envelope, and PCM samples; the C audio task only performs non-blocking playback. The chime can be disabled in Settings.
- **BLE keyboard**: pair the device named `FoloPassKey` with no passkey, focus a field on the host, and select **Send** to type the current password as a US-layout keyboard. The bonded link is encrypted, but Just Works pairing does not provide MITM authentication.
- **Display**: switchable 240×320 cyberpunk and blue-sky themes with a 17px, 4bpp, strongly hinted CJK subset. MoonBit view models own parameter slots, focus, layout, theme and settings state, strength color, and battery presentation policy.
- **Core**: generation, unbiased indexes, output postconditions, entropy and strength, state transitions, settings input policy, view models, battery policy, and sound synthesis are implemented in MoonBit.

## Reusable engine and applications

The project now has a library-first boundary instead of exposing generation
only as firmware internals:

- [`src`](src/api.mbt) is the root, platform-neutral MoonBit package; its
  [API guide](docs/api/README.md) covers the typed `PasswordPolicy`,
  String-returning application APIs, allocation-controlled embedded APIs, and
  injected random source.
- [`src/cmd/securegen`](src/cmd/securegen/main.mbt) is an independent
  MoonBit application using host cryptographic entropy through
  `moonbitlang/core/env`; it supports profiles, custom lengths, PINs, and batch output.
- [`examples/consumer`](examples/consumer/README.md) is a separate MoonBit
  module with a versioned dependency on the root library and cross-module tests.
- [`src/cmd/web`](src/cmd/web/main.mbt) and
  [`examples/web`](examples/web/README.md) form a browser consumer: MoonBit owns
  the credential workflow while the adapter supplies DOM access and browser
  cryptographic randomness.
- The AI Passport firmware is a second, real application. Its stable C ABI now
  delegates password, PIN, and passphrase generation to `securegen` while C
  continues to provide hardware entropy and device I/O.

This separation lets Native, Wasm, browser, command-line, and embedded consumers
share the same engine without depending on ESP-IDF, LVGL, BLE, or FoloToy code.

## Settings and persistence

- Long-press `OK` on the main screen while not editing to switch between cyberpunk and blue-sky themes. Long-press `DOWN` to open Settings.
- Use `UP` / `DOWN` to select **Theme** or **Sound**, press `OK` to change the selected value, and long-press `OK` to return.
- **Theme** switches between the dark cyberpunk interface and the blue-sky, clouds, and grass interface.
- **Sound** enables or disables the success chime without affecting password generation.
- Theme and sound preferences and up to three BLE bond records are stored in ESP-IDF NVS. Generated passwords and password history are never persisted.
- If NVS is unavailable, the selected values still apply for the current session and the firmware logs a warning. The application does not erase the NVS partition automatically.

## MoonBit-first implementation

The repository now contains 4,883 physical production `.mbt` lines and 2,722 MoonBit test and application lines, 7,605 in total across 46 tracked MoonBit files. Excluding tests, applications, blank lines, and comments leaves 3,632 effective production MoonBit lines: 775 in the root library and 2,857 in the firmware adapter. `tools/check_repo.py` scans both the root library and firmware adapter and independently enforces at least 1,000 effective production lines; tests and applications cannot satisfy that gate.

The figures above were measured on the tree of release commit `8b4e466`. Re-run
`python tools/check_repo.py` for the effective production line count, the
`moon test` commands in [Test](#test) for the per-suite test totals, and
`git rev-list --count HEAD` for the commit count.

The production MoonBit modules are compiled into and called by the ESP-IDF firmware. They own:

- Random password, PIN, and passphrase algorithms plus enabled-class guarantees;
- the RandomSource abstraction, rejection sampling, and generated-output postconditions;
- parameter policies, entropy estimates, and strength classification;
- NAVIGATION / EDITING transitions and configuration change detection;
- settings focus, button-gesture mapping, theme selection, and sound policy;
- parameter slot, coordinate, focus, editing, and value view models;
- pure policy for resolving raw CW2017 readings into a display value;
- BLE keyboard state, send eligibility, and the complete printable-ASCII to USB HID report mapping;
- success-note sequencing, attack/release envelopes, and PCM sample generation.

C is restricted to ESP-IDF/BSP initialization, LVGL widget calls, raw I2C readings, FreeRTOS scheduling, the NVS persistence adapter, NimBLE HID transport, codec writes, the secure-random source, and Flash dictionary access.

## Upstream and attribution

This project is built on the open-source [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) firmware and hardware support stack.

The upstream FoloToy AI Passport project is licensed under the MIT License.
Its original copyright and license notices are retained in this repository.

This repository adds the MoonBit-based password generator, product logic, interaction design, UI, tests, documentation, and related firmware modifications for MoonBit Hackathon 2026.

## Toolchains

- ESP-IDF 5.5.3, target `esp32c3`
- MoonBit with `moonc` 0.10.14 or newer and the native/C backend (`moon` and
  `moonc` on `PATH`)
- Python 3

The static gate runs [`tools/check_moonc_version.py`](tools/check_moonc_version.py)
and rejects older compilers before checking or testing the project. The ESP-IDF
build invokes [`tools/generate_moonbit.py`](tools/generate_moonbit.py), which
compiles the reusable `securegen` package and the firmware adapter package to
portable C, then links them into the `moonbit_password` ESP-IDF component.
Generated C is a build artifact and is not committed.

GitHub Actions installs MoonBit's `latest` stable channel because dated CLI
bundles are not guaranteed to remain downloadable from the official CDN. The
minimum-version gate prevents `latest` from silently resolving below the
competition baseline, and each run prints its exact tool versions.

## Test

Run the full static and host-test gate:

```bash
./tools/validate.sh --static
```

Run the MoonBit core directly:

```bash
moon check --target wasm-gc --deny-warn
MOONBIT_NEW_NATIVE=0 moon -C examples/folotoy-ai-passport/moonbit \
  check --target native --deny-warn
MOONBIT_NEW_NATIVE=0 moon -C examples/folotoy-ai-passport/moonbit \
  test --target native --release
```

The reusable package also has a backend-independent gate that runs on WasmGC:

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon -C examples/consumer test --target js --release --deny-warn
moon run src/cmd/securegen --target js --release -- --profile strict --length 24
```

Deterministic sources are used only by tests. The CLI uses host cryptographic entropy; firmware randomness crosses the C FFI boundary into the ESP32 adapter.

## Build

Activate ESP-IDF 5.5.3, ensure MoonBit is on `PATH`, then run:

```bash
./tools/validate.sh --firmware
```

To run every gate:

```bash
./tools/validate.sh
```

The firmware gate uses a fresh temporary build, runs `idf.py build`, creates a merged flash image with `idf.py merge-bin`, verifies its component offsets and partition bounds, and copies only the checked image to:

```text
build/FoloToy-AI-Passport-full.bin
```

`build/FoloToy-AI-Passport.bin` is only the application image and is not a substitute for the merged firmware.

On Windows, use an ESP-IDF PowerShell followed by Git Bash, or pass the active ESP-IDF Python explicitly if the Microsoft Store `python3` alias is unusable:

```bash
PYTHON='D:/path/to/idf-python/Scripts/python.exe' ./tools/validate.sh --static
```

If a constrained Windows environment cannot write to the configured ccache directory, set `IDF_NO_CCACHE=1` for the firmware gate. CI keeps ccache enabled by default.

## Flash

The merged image is written at offset `0x0`:

```bash
python -m esptool --chip esp32c3 --baud 460800 \
  --before default-reset --after hard-reset \
  write-flash 0x0 build/FoloToy-AI-Passport-full.bin
```

Alternatively, use the official AI Passport web flasher and select the same `-full.bin` file. Successful compilation or flashing is not evidence that the UI, buttons, fonts, power behavior, and RNG adapter have passed physical-device acceptance.

Flashing the merged image at `0x0` can reset the NVS region. After initial provisioning, use segmented `idf.py flash` during development when existing theme and sound preferences must be preserved.

## Offline word list and fonts

- The memorable mode bundles the 1,296-entry [EFF Short Wordlist for Passphrases #1](https://www.eff.org/files/2016/09/08/eff_short_wordlist_1.txt), attributed to the Electronic Frontier Foundation under CC BY 3.0 US. The tracked source SHA-256 is `8f5ca830b8bffb6fe39c9736c024a00a6a6411adb3f83a9be8bfeeb6e067ae69`.
- Build-time code generation packs all words into one NUL-separated constant byte blob with 16-bit offsets. The table remains in Flash and is not loaded wholesale into RAM at startup.
- The Chinese LVGL glyph subset was generated from Noto Sans SC. Its OFL 1.1 notice is tracked at [`assets/fonts/NotoSansSC-OFL.txt`](assets/fonts/NotoSansSC-OFL.txt). Only ASCII and V1 UI glyphs are compiled into the firmware; the current subset uses 17px, 4bpp, and strong autohinting for heavier small-screen strokes.
- The subset uses LVGL's compressed font format, so `examples/folotoy-ai-passport/sdkconfig.defaults` enables `CONFIG_LV_USE_FONT_COMPRESSED=y`. If panels and the generated password render but title, mode, and button labels are blank, rebuild from clean defaults and confirm this option is present in the generated `sdkconfig`.
- The vendored MoonBit runtime files retain their Apache-2.0 notice in [`examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt`](examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt). Project-authored code remains under the repository MIT license.

## API, versioning, design, and security

- [Public API guide](docs/api/README.md)
- [Semantic versioning and Mooncakes release contract](docs/api/VERSIONING.md)
- [Architecture and decision record](docs/application/ARCHITECTURE.md)
- [Security model and limitations](docs/application/SECURITY.md)
- [AI usage disclosure](docs/application/AI_USAGE.md)
- [Official AI Passport documentation index](docs/README.md)

## Verification status

The current tree defines 122 MoonBit tests, and every suite passes when run on
this machine: 12 in the portable root library (WasmGC and JavaScript), 3 in the
CLI, 2 in the browser command, 2 in the separate-module consumer, and 103 in the
firmware adapter (Native). CI rejects `moonc` older than
0.10.14, runs repository and package-boundary checks, executes the portable
library, CLI, browser, cross-package, firmware-adapter, and 21 Python tests (11
firmware-layout, 7 screenshot conversion, 3 compiler-version gate), and
builds and verifies the merged ESP-IDF image. BLE pairing and typing, the
dual-theme Settings screen, preference persistence across reboot, sound toggle,
fonts, buttons, battery behavior, and RNG adapter still require physical-device
validation.
