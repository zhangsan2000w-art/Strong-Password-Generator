# Independent MoonBit consumer

English | [简体中文](README.zh_CN.md)

This module is intentionally separate from the publishable root module. Its
`moon.mod` declares `zhangsan2000w-art/moonbit-securegen@0.1.0`, the same shape
that an external project uses after running:

```bash
moon add zhangsan2000w-art/moonbit-securegen
```

The repository workspace resolves that dependency to the local root module for
development. The consumer imports only the public API and provides the
cross-module integration gate:

```bash
moon -C examples/consumer test --target wasm-gc --release --deny-warn
```

The deterministic source in the test is only for repeatability. Applications
must inject a cryptographically secure random source provided by their target
platform.
