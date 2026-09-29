# Reviewer guide: SecureGen for MoonBit

English | [简体中文](REVIEW_GUIDE.zh_CN.md)

This is the shortest path for evaluating the MoonBit work without first
building or owning FoloToy hardware. The one-page submission brief is
[APPLICATION.md](APPLICATION.md).

## Acceptance evidence

| Requirement | Repository evidence |
| --- | --- |
| MoonBit-first, `moonc >= 0.10.14` | The root library and product policy are MoonBit; `tools/check_moonc_version.py` is a hard static/CI gate. Generated font C and the vendored runtime are identified through `.gitattributes`. |
| Public repository and history | The GitHub remote keeps focused Conventional Commit history. Repository visibility is an account setting, so confirm that reviewers can reach it before submitting. |
| Clear source and working core | `src` is the portable library; adapters and applications are under `src/cmd` and `examples`. |
| Reproducible README | The root README gives the goal, `moon add` installation, package import, CLI commands, browser instructions, and consumer links. |
| CI check/build/test | `static-checks.yml` and `firmware-checks.yml` call the shared `tools/validate.sh` gates. |
| Runnable examples | CLI, browser, separate-module consumer, and FoloToy firmware examples are included. |
| Core tests | 122 MoonBit tests (12 portable library, 3 CLI, 2 browser command, 2 separate-module consumer, 103 firmware adapter) plus 21 Python host tests cover generation, validation, entropy, consumers, adapters, and firmware layout. |
| MoonBit implementation scale | `python tools/check_repo.py` reports 3,632 effective production MoonBit lines (775 root library plus 2,857 firmware adapter) against a 1,000-line floor; 4,883 physical production `.mbt` lines. |
| Mooncakes | `zhangsan2000w-art/moonbit-securegen@0.1.1` is installable with `moon add`; a scratch module on this machine resolved and downloaded exactly that version from the registry. |
| OSI license and attribution | Root code uses MIT; the upstream FoloToy MIT notice is retained, and the EFF wordlist, Noto Sans SC, and MoonBit runtime notices are documented. [APPLICATION.md](APPLICATION.md#sources-porting-and-licenses) lists each origin together with the tracked file that carries its notice. |

## What is the reusable artifact?

The repository root is the publishable `zhangsan2000w-art/moonbit-securegen`
module, and `src` is its platform-neutral root package. Its public surface
includes:

- typed password and passphrase policies;
- password, passphrase, and PIN APIs returning MoonBit `String`;
- a typed `RandomSource`, public validators, entropy estimators, and strength
  bands;
- allocation-controlled password, PIN, and passphrase APIs for embedded use;
- unbiased random-index selection;
- a caller-injected `() -> UInt` entropy interface.

The package imports no firmware, UI, BLE, filesystem, network, or ESP-IDF code.
Randomness is deliberately injected so each consumer can use its platform's
cryptographic source while tests can use deterministic sequences.

## Which applications consume it?

1. `src/cmd/securegen` is an independent host application. It uses
   `moonbitlang/core/env` cryptographic entropy and supports policy selection,
   custom lengths, PIN output, and batch generation.
2. `src/cmd/web` plus `examples/web` is a browser consumer whose DOM and secure
   random bindings are target adapters; credential logic stays in the library.
3. `examples/consumer` is a separate module declaring a versioned library
   dependency and exercising only the public API.
4. `examples/folotoy-ai-passport/moonbit` is the FoloToy firmware adapter. It
   preserves the device C ABI but delegates password, PIN, and passphrase
   generation to `securegen`.

The CLI does not import the firmware adapter, and the portable package does not
import either application.

## Verify without hardware

From the repository root:

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/securegen \
  --target js --release --deny-warn
moon -C examples/consumer test --target wasm-gc --release --deny-warn
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/web \
  --target js --release --deny-warn
MOONBIT_NEW_NATIVE=0 moon test \
  -p zhangsan2000w-art/moonbit-securegen-folotoy --target native --release
moon build --target js --release --deny-warn
node examples/web/smoke.mjs
moon run src/cmd/securegen --target js --release -- \
  --profile strict --length 24 --count 3
python tools/check_repo.py
```

Each `moon test` command prints its own total: 12 portable library tests,
3 CLI tests, 2 separate-module consumer tests, 2 browser-command tests, and 103
firmware-adapter tests. The native adapter suite needs a host C compiler; on
Windows use a MinGW `gcc` and keep an unusable `cl` off `PATH`.
`node examples/web/smoke.mjs` exercises the generated browser bundle, the
`moon run` command performs a live generation journey with host cryptographic
entropy, and `python tools/check_repo.py` verifies repository boundaries and
prints the effective MoonBit implementation size.

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
