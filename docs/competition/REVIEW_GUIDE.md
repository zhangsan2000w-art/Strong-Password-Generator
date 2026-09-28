# Reviewer guide: SecureGen for MoonBit

English | [简体中文](REVIEW_GUIDE.zh_CN.md)

This is the shortest path for evaluating the MoonBit work without first
building or owning FoloToy hardware.

## What is the reusable artifact?

`moonbit/securegen` is a platform-neutral MoonBit package. Its public surface
includes:

- typed `PasswordPolicy` presets and custom policies;
- `generate_password` and `generate_pin` APIs returning MoonBit `String`;
- allocation-controlled password, PIN, and passphrase APIs for embedded use;
- unbiased random-index selection;
- a caller-injected `() -> UInt` entropy interface.

The package imports no firmware, UI, BLE, filesystem, network, or ESP-IDF code.
Randomness is deliberately injected so each consumer can use its platform's
cryptographic source while tests can use deterministic sequences.

## Which applications consume it?

1. `moonbit/examples/cli` is an independent host application. It uses
   `moonbitlang/core/env` cryptographic entropy and supports policy selection,
   custom lengths, PIN output, and batch generation.
2. The repository-root MoonBit package is the FoloToy firmware adapter. It
   preserves the device C ABI but delegates password, PIN, and passphrase
   generation to `securegen`.

The CLI does not import the firmware adapter, and the portable package does not
import either application.

## Verify without hardware

From the repository root:

```bash
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/securegen \
  --target wasm-gc --release --deny-warn
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/examples/cli \
  --target js --release --deny-warn
moon -C moonbit run examples/cli --target js --release -- \
  --profile strict --length 24 --count 3
python tools/check_repo.py
```

The first command exercises the portable engine, the second checks application
argument and policy behavior, the third performs a live generation journey with
host cryptographic entropy, and the fourth verifies repository boundaries and
effective MoonBit implementation size.

## Verify the embedded consumer

With ESP-IDF 5.5.3 activated:

```bash
./tools/validate.sh --firmware
```

The firmware gate builds from a fresh directory, compiles the portable package
and firmware adapter separately, links both MoonBit cores to C, builds the
ESP32-C3 image, merges flash components, and verifies offsets and partition
bounds.

## Evidence boundaries

- Portable engine tests and CLI tests are host evidence.
- A successful ESP-IDF build and merged-image check are build evidence.
- BLE pairing, reconnect, bond persistence, display interaction, and exact HID
  typing remain device acceptance checks and must not be inferred from builds.
- The project does not claim that deterministic test sources generate real
  secrets. The CLI and firmware use their own cryptographic platform sources.
