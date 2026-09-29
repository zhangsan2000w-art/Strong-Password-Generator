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
| Effective production MoonBit lines | 3,821 (775 root library + 3,046 adapter) against a 1,000 floor | `python tools/check_repo.py` |
| Physical production `.mbt` lines | 5,228 | raw line count over the same file set that `moonbit_product_lines()` in `tools/check_repo.py` scans |
| MoonBit test and application lines | 2,970 (8,198 MoonBit lines in total across 46 tracked files) | same scope, with tests and applications counted |
| MoonBit tests | 139 passing: 12 library, 3 CLI, 2 browser, 2 consumer, 120 adapter | per-package `moon test` commands in `REVIEW_GUIDE.md` |
| Python host tests | 21 passing: 11 layout, 11 screenshot conversion, 3 compiler gate | `python tests/test_verify_firmware.py` and siblings |
| Commits | 42, all dated 2026-08-07 to 2026-09-29 | `git rev-list --count HEAD` at `8b4e466` |

## Claim audit

| Entry requirement | Status | Evidence or caveat |
| --- | --- | --- |
| MoonBit project identity | Verified | Root module is a MoonBit library; the gate in `tools/check_repo.py` fails the build if production MoonBit drops below 1,000 effective lines. |
| More than 1,000 effective MoonBit lines | Verified | 3,821 reported by `python tools/check_repo.py` on this tree. |
| Competition-period commits and a working MVP | Verified, window not checked | 42 commits dated 2026-08-07 to 2026-09-29; the MoonBit library, CLI, and browser MVP runs with the commands in `REVIEW_GUIDE.md` without hardware. Whether those dates fall inside the organizers' submission window is the maintainer's check, not a repository fact. |
| Root library free of C FFI, BLE, LVGL, NVS | Verified | `src/moon.pkg` imports only `moonbitlang/core/debug` and `core/test`; no `extern` in `src/api.mbt` or `src/typed_api.mbt`. |
| Mooncakes package at 0.1.1 | Verified | `moon add zhangsan2000w-art/moonbit-securegen` in a scratch module resolved and downloaded `0.1.1` from the registry on this machine. The cached artifact carries `moon.mod` with `version = "0.1.1"`, `src/api.mbt`, `src/typed_api.mbt`, `src/moon.pkg`, both command packages, the consumer and browser examples, and `LICENSE`; it contains no firmware, tools, or workflow files. [`VERSIONING.md`](../api/VERSIONING.md) defines the release contract. |
| Native, Wasm, CLI, Web, consumer, tests, CI | Verified | `./tools/validate.sh --static` now passes end to end: repository checks, the `moonc >= 0.10.14` gate, five MoonBit suites under `--deny-warn`, the CLI live-generation run, the browser smoke test, the publish-package boundary check, actionlint, and 25 Python host tests. It needs a compiler at `moonc 0.10.14` or newer; the official `latest` bundle provides it, and CI installs that bundle on every run through [`static-checks.yml`](../../.github/workflows/static-checks.yml). |
| ESP-IDF firmware build | Verified | `./tools/validate.sh --firmware` completes from a fresh build directory on ESP-IDF 5.5.3 with `moonc 0.10.14`: the portable package and the firmware adapter are emitted to C, linked into the ESP32-C3 application, and the merged flash image is verified (bootloader 21,024 bytes at `0x0`, partition table 3,072 bytes at `0x8000`, application 1,140,064 bytes inside the 8,323,072-byte `factory` partition at `0x10000`, merged image 1,205,600 bytes). The same image was then flashed and booted on hardware. |
| Physical device acceptance | Partially verified | Observed on a real AI Passport for the band-stream build (`46a370e`): boot to `Ready: secure_random=1 buttons=1 ble_keyboard=1`, advertising as `FoloPassKey`, correct panel and CJK glyph rendering, and repeated `FAP_SCREENSHOT_V1` captures while the keyboard stayed advertising. Not covered: pairing with a real host, HID typing into it, the three button gestures, the Settings screen, preference persistence across reboot, the sound toggle, and battery behaviour over time. The pairing watchdog and label-glyph ports on top of that build are host- and build-verified only; the device was unplugged before the newer image could be flashed. |

## Sources, porting, and licenses

Project-authored code is MIT. Every other component below was either carried over
from upstream or fetched at build time, and each has a declaration inside this
repository.

| Component | Origin | License | Declaration in this repository |
| --- | --- | --- | --- |
| MoonBit library, CLI, browser page, consumer module, adapter logic, tests, documentation | authored for this project with the AI assistance disclosed in [`AI_USAGE.md`](../application/AI_USAGE.md) | MIT | [`LICENSE`](../../LICENSE) |
| FoloToy AI Passport firmware, BSP, components, hardware documentation | upstream `FoloToy/ai-passport` (Gitee and GitHub), relocated unchanged into `examples/folotoy-ai-passport` by commit `5f19183` | MIT | the retained [`LICENSE`](../../LICENSE), which still carries `Copyright (c) 2026 FoloToy`, plus the upstream section of the root README |
| EFF Short Wordlist for Passphrases #1, 1,296 entries | Electronic Frontier Foundation | CC BY 3.0 US | tracked verbatim at [`assets/wordlists/eff-short-wordlist-1.txt`](../../assets/wordlists/eff-short-wordlist-1.txt), pinned to SHA-256 `8f5ca830b8bffb6fe39c9736c024a00a6a6411adb3f83a9be8bfeeb6e067ae69` in the root README and expanded into the Flash table by `tools/generate_wordlist.py` |
| Noto Sans SC | Google | SIL Open Font License 1.1 | notice tracked at [`assets/fonts/NotoSansSC-OFL.txt`](../../assets/fonts/NotoSansSC-OFL.txt); the derived LVGL glyph subset `examples/folotoy-ai-passport/main/passport_font_zh_16.c` is marked generated in [`.gitattributes`](../../.gitattributes) |
| MoonBit native runtime C headers and `runtime.c` | the MoonBit native runtime distributed with the toolchain, vendored for the ESP-IDF build | Apache-2.0 | [`examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt`](../../examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt), with the `runtime/` directory marked vendored in [`.gitattributes`](../../.gitattributes) |
| LVGL and the four Espressif components | ESP-IDF Component Manager, resolved at build time | LVGL MIT; Espressif components Apache-2.0 | not committed: `managed_components/` is listed in [`.gitignore`](../../.gitignore), so each build re-fetches them with their own license files |

Product logic migrated out of C into MoonBit in commits `bda1591` (reusable
generation engine), `115be24` and `b14c669` (remaining screen wording and the last
test-only logic), and `d29460c` (typed credential API). C now keeps BSP and
ESP-IDF initialization, LVGL widget calls, the NimBLE transport, NVS access, codec
writes, and the platform random source.

## Boundaries of this claim

This brief describes only the `Strong-Password-Generator_AI-Passport` repository. It
does not resolve, absorb, or speak for the separate review outcome of
`ai-passport-codex-buddy`; that entry keeps its own history and its own rejection
reasons. Project-authored code is MIT, and the upstream and third-party notices are
the table above plus the root [LICENSE](../../LICENSE).
