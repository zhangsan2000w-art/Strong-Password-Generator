# Versioning and Mooncakes releases

English | [简体中文](VERSIONING.zh_CN.md)

`zhangsan2000w-art/moonbit-securegen` follows Semantic Versioning. The version
in the root `moon.mod` is the single source of truth for the library and is the
version published to Mooncakes.

## Compatibility contract

- **Patch** (`0.1.1`) fixes behavior or documentation without intentionally
  changing a public signature or valid output contract.
- **Minor** (`0.2.0`) may add APIs. While the project is below `1.0.0`, a minor
  release may also remove or change experimental APIs, but the release notes
  must call this out explicitly and provide a migration example.
- **Major** (`1.0.0`) is required after stabilization for incompatible public
  API or behavioral-contract changes.
- `src` is the public library boundary. `src/cmd/*` and `examples/*` are
  consumers and adapters; their UI or command-line changes do not by
  themselves break the library API.
- Native, WasmGC, and JavaScript are supported library targets. A release must
  keep portable library tests passing on WasmGC and JavaScript and keep Native
  code generation passing.

Deprecated APIs remain available for at least one minor release where
practical. Security fixes may require a faster removal; the release notes must
describe the risk and replacement.

## Release checklist

1. Update `moon.mod` and the versioned dependency in
   `examples/consumer/moon.mod` together.
2. Update the bilingual changelog with user-visible library changes and any
   migration notes.
3. Run `./tools/validate.sh --static` on Linux or an equivalent environment.
4. Inspect `moon package --list`; firmware, C FFI, BLE, LVGL, NVS, tools, CI,
   and build outputs must not become library dependencies or package payload.
5. Run `moon publish --dry-run`, review the generated package, then run
   `moon publish` from an account whose Mooncakes username owns the module
   namespace.
6. Verify that a fresh project can run
   `moon add zhangsan2000w-art/moonbit-securegen` and pass the consumer tests.

Published versions are immutable. Never reuse a version number after a failed
or partial release; fix the issue and increment the version.
