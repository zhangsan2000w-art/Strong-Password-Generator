# SecureGen CLI

English | [简体中文](README.zh_CN.md)

An independent MoonBit application built on the reusable `securegen` package.
It obtains cryptographically secure random bytes from `moonbitlang/core/env`
and does not depend on ESP-IDF, FoloToy, LVGL, BLE, or device firmware.

## Run

```bash
moon run src/cmd/securegen --target js --release -- --help
moon run src/cmd/securegen --target js --release -- --profile strict --length 24
moon run src/cmd/securegen --target js --release -- --pin 8 --count 3
```

Options:

- `--profile compatible|standard|strict` selects a password policy.
- `--length N` overrides password length from 4 to 128.
- `--pin N` generates a decimal PIN from 4 to 32 digits instead of a password.
- `--count N` prints between 1 and 100 independently generated values.

## Security

The application refuses to substitute a deterministic fallback if the host
cannot provide secure entropy. Generated secrets are printed to standard
output, so avoid terminal recording, shared logs, and copied shell output.

The generation algorithms remain in the root `src` package; this directory is
a consumer application and a reference integration for other MoonBit projects.
