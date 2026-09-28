# SecureGen

[简体中文](README.zh_CN.md) | English

`securegen` is a platform-neutral MoonBit package for generating random
passwords, PINs, and dictionary-backed passphrases. It is the reusable engine
behind the AI Passport firmware, not a wrapper around ESP-IDF or FoloToy APIs.

## Public API

- `PasswordPolicy` provides typed compatible, standard, strict, and custom
  policies.
- `generate_password` and `generate_pin` return ordinary MoonBit `String`
  values for application code.
- `generate_password_into`, `generate_pin_into`, and
  `generate_passphrase_into` write to a caller-owned sink for constrained or
  embedded consumers.
- Every generation API receives `next_u32 : () -> UInt`; the package never
  silently substitutes a weak random source.

```moonbit
let policy = @securegen.PasswordPolicy::standard()
match @securegen.generate_password(policy, secure_random_u32) {
  Ok(secret) => use_secret(secret)
  Err(message) => report_error(message)
}
```

The module currently verifies the package with the Native checker and executes
its tests on WasmGC. The code does not import firmware, filesystem, network, UI,
or operating-system packages.

## Applications

- `../examples/cli` is an independent MoonBit consumer that obtains
  cryptographically secure entropy through `moonbitlang/core/env`. It supports
  password profiles, custom lengths, PINs, and multiple generated values.
- The repository-root MoonBit package is a Native foreign-library adapter used
  by the FoloToy AI Passport firmware. Its existing C ABI delegates generation
  to `securegen`.

Run the portable package tests and example:

```bash
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/securegen \
  --target wasm-gc --release --deny-warn
moon -C moonbit run examples/cli --target js --release -- --profile strict --length 24
```

## Security boundary

The caller owns entropy quality, secret display, storage, transmission, and
zeroization. A deterministic callback is useful for tests but is not a secure
random source. The CLI uses the host environment's cryptographic random source;
the FoloToy application injects its platform RNG through the C FFI boundary.
