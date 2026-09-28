# SecureGen

[简体中文](README.zh_CN.md) | English

`securegen` is a platform-neutral MoonBit package for generating random
passwords, PINs, and dictionary-backed passphrases. It is the reusable engine
behind the AI Passport firmware, not a wrapper around ESP-IDF or FoloToy APIs.

## Public API

- `PasswordPolicy` provides typed compatible, standard, strict, and custom
  policies.
- `PassphrasePolicy` and `PassphraseSeparator` make dictionary-based output a
  typed application API instead of an embedded-only callback surface.
- `generate_password`, `generate_pin`, and `generate_passphrase` return
  ordinary MoonBit `String` values for application code.
- `generate_password_into`, `generate_pin_into`, and
  `generate_passphrase_into` write to a caller-owned sink for constrained or
  embedded consumers.
- `RandomSource` is the typed entropy boundary; callback overloads remain
  available for allocation-controlled and C-compatible adapters.
- `validate_password` and `validate_pin` check generated or imported values.
- entropy estimators report tenths of a bit, and `Strength` maps estimates to
  presentation bands without claiming that the caller's RNG is secure.

```moonbit
let policy = @securegen.PasswordPolicy::standard()
let random = @securegen.RandomSource::new(secure_random_u32)
match @securegen.generate_password_with_source(policy, random) {
  Ok(secret) => use_secret(secret)
  Err(message) => report_error(message)
}
```

Password lengths are supported from 4 to 128 characters and PINs from 4 to 32
digits. Platform adapters may apply narrower product limits. The module checks
the package for Native and executes its portable tests on WasmGC and JavaScript.
The code does not import firmware, filesystem, network, UI, or operating-system
packages.

## Applications

- [`../../src/cmd/securegen`](../../src/cmd/securegen/main.mbt) is an
  independent MoonBit consumer that obtains
  cryptographically secure entropy through `moonbitlang/core/env`. It supports
  password profiles, custom lengths, PINs, and multiple generated values.
- [`../../src/cmd/web`](../../src/cmd/web/main.mbt) is a JavaScript-target
  MoonBit browser adapter. The matching
  [`../../examples/web`](../../examples/web/README.md) page exercises password,
  PIN, and passphrase flows without copying generation logic into JavaScript.
- [`../../examples/consumer`](../../examples/consumer/README.md) is a separate
  module with a versioned dependency and cross-package integration tests.
- The `examples/folotoy-ai-passport/moonbit` workspace member is a Native
  foreign-library adapter used
  by the FoloToy AI Passport firmware. Its existing C ABI delegates generation
  to `securegen`.

Run the portable package tests and example:

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon run src/cmd/securegen --target js --release -- --profile strict --length 24
```

## Security boundary

The caller owns entropy quality, secret display, storage, transmission, and
zeroization. A deterministic callback is useful for tests but is not a secure
random source. The CLI uses the host environment's cryptographic random source;
the FoloToy application injects its platform RNG through the C FFI boundary.
Entropy functions estimate a policy's search space; they do not measure runtime
randomness, password reuse, online rate limits, or resistance to user-chosen
patterns.

See [Versioning and Mooncakes releases](VERSIONING.md) for the compatibility
contract and release checklist.
