# SecureGen for MoonBit

English | [简体中文](APPLICATION.zh_CN.md)

One-page submission brief. For the reviewer walkthrough use
[REVIEW_GUIDE.md](REVIEW_GUIDE.md); for the AI-assistance disclosure use
[AI_USAGE.md](../application/AI_USAGE.md).

## What is submitted

`zhangsan2000w-art/moonbit-securegen` is a publishable, reusable MoonBit library of
credential generators and security policies. It is not a firmware application, and
the entry point is not a device demo. The submission boundary is the root MoonBit
module declared by [`moon.mod`](../../moon.mod) at version `0.1.1`, whose public
surface is the platform-neutral root package [`src`](../../src/api.mbt). A consumer
installs it with `moon add zhangsan2000w-art/moonbit-securegen` and needs no
ESP-IDF, LVGL, BLE, NVS, filesystem, network, or FoloToy code.

## What the library provides

| Capability | Public surface |
| --- | --- |
| Typed password policy | `PasswordPolicy::{new, compatible, standard, strict}`, `with_length`, `is_valid` |
| Typed passphrase policy | `PassphrasePolicy::{new, standard}`, `word_count`, `PassphraseSeparator::{hyphen, period, underscore}` |
| Random source abstraction | `RandomSource::new(() -> UInt)`; every generator also takes a bare `() -> UInt` |
| Password, passphrase, PIN | `generate_password`, `generate_passphrase`, `generate_pin`, plus `*_with_source` variants returning `Result[String, String]` |
| Allocation-controlled embedded APIs | `generate_password_into`, `generate_pin_into`, `generate_passphrase_into`, `generate_password_compat` against a caller-owned `emit : (Int) -> Bool` sink |
| Output validation | `validate_password`, `validate_pin` |
| Entropy estimation and strength bands | `PasswordPolicy::estimated_entropy_bits_x10`, `estimate_pin_entropy_bits_x10`, `estimate_passphrase_entropy_bits_x10`, `Strength`, `strength_from_entropy_x10` |
| Unbiased index selection | `unbiased_index` rejection sampling |

The root package imports only `moonbitlang/core/debug` (plus `core/test` for white-box
tests), as declared in [`src/moon.pkg`](../../src/moon.pkg). There is no `extern`
declaration, C FFI, or platform binding anywhere in `src` outside `src/cmd`.
Randomness is caller-injected on purpose: each target supplies its own cryptographic
source, while tests use deterministic sequences. The library never presents a
deterministic test source as a real secret generator.

## Targets and consumers

`supported_targets = "all"` with `preferred_target = "wasm-gc"`, so the same engine
runs on Native, WasmGC, and JavaScript. Four independent consumers prove it:

1. [`src/cmd/securegen`](../../src/cmd/securegen/main.mbt) — command-line host
   application using `moonbitlang/core/env` cryptographic entropy.
2. [`src/cmd/web`](../../src/cmd/web/main.mbt) with
   [`examples/web`](../../examples/web/README.md) — browser consumer; only DOM and
   `crypto` bindings are target adapters.
3. [`examples/consumer`](../../examples/consumer/README.md) — a separate MoonBit
   module declaring a versioned dependency on the library and using only its public
   API.
4. [`examples/folotoy-ai-passport/moonbit`](../../examples/folotoy-ai-passport/moonbit)
   — the embedded adapter described next.

## FoloToy is one embedded example, not the project

`examples/folotoy-ai-passport` holds the FoloToy AI Passport firmware that was already
upstream. It exists in this repository to show that the allocation-controlled APIs
work on a real ESP32-C3 target with 8 MB flash and no PSRAM, where C keeps hardware
glue (BSP, LVGL, NimBLE transport, NVS, codec) and delegates every credential decision
to `securegen`. Removing that directory leaves the library, CLI, browser page, and
consumer module fully usable and testable, which is exactly what
`python tools/check_repo.py` and the commands in `REVIEW_GUIDE.md` demonstrate without
hardware.

## Metrics, as measured on this tree

| Metric | Value | How to reproduce |
| --- | --- | --- |
| Effective production MoonBit lines | 3,632 (775 root library + 2,857 adapter) against a 1,000 floor | `python tools/check_repo.py` |
| Physical production `.mbt` lines | 4,883 | raw line count over the same file set that `moonbit_product_lines()` in `tools/check_repo.py` scans |
| MoonBit test and application lines | 2,722 (7,605 MoonBit lines in total across 46 tracked files) | same scope, with tests and applications counted |
| MoonBit tests | 122 passing: 12 library, 3 CLI, 2 browser, 2 consumer, 103 adapter | per-package `moon test` commands in `REVIEW_GUIDE.md` |
| Python host tests | 21 passing: 11 layout, 7 screenshot conversion, 3 compiler gate | `python tests/test_verify_firmware.py` and siblings |
| Commits | 42, all dated 2026-08-07 to 2026-09-29 | `git rev-list --count HEAD` at `8b4e466` |

## Claim audit

| Entry requirement | Status | Evidence or caveat |
| --- | --- | --- |
| MoonBit project identity | Verified | Root module is a MoonBit library; the gate in `tools/check_repo.py` fails the build if production MoonBit drops below 1,000 effective lines. |
| More than 1,000 effective MoonBit lines | Verified | 3,632 reported by `python tools/check_repo.py` on this tree. |
| Competition-period commits and a working MVP | Verified | 42 commits; the MVP is the library plus CLI and browser page, runnable with the commands in `REVIEW_GUIDE.md` without hardware. |
| Root library free of C FFI, BLE, LVGL, NVS | Verified | `src/moon.pkg` imports only `moonbitlang/core/debug` and `core/test`; no `extern` in `src/api.mbt` or `src/typed_api.mbt`. |
| Mooncakes package at 0.1.1 | Partially verified | `moon.mod` declares `0.1.1` and [`VERSIONING.md`](../api/VERSIONING.md) defines the release contract. Registry availability was not queried from this machine; publishing is a manual maintainer action. |
| Native, Wasm, CLI, Web, consumer, tests, CI | Verified by execution, with one toolchain caveat | All five suites pass locally. `./tools/validate.sh --static` still aborts here because the installed `moonc` is 0.10.12 while the entry gate requires 0.10.14; the gate itself is enforced in [`static-checks.yml`](../../.github/workflows/static-checks.yml). Update the local toolchain and re-run before submission. |
| ESP-IDF firmware build | Not re-run in this pass | Requires an activated ESP-IDF 5.5.3 environment; run `./tools/validate.sh --firmware`. |
| Physical device acceptance | Not verified | BLE pairing and typing, display, fonts, buttons, battery, and persistence remain device checks. A successful build is not device evidence. |

## Boundaries of this claim

This brief describes only the `Strong-Password-Generator_AI-Passport` repository. It
does not resolve, absorb, or speak for the separate review outcome of
`ai-passport-codex-buddy`; that entry keeps its own history and its own rejection
reasons. Project-authored code is MIT, with upstream and third-party notices listed in
the next section of this document and in the root
[LICENSE](../../LICENSE).
