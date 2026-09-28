# SecureGen

[English](README.md) | 简体中文

`securegen` 是一个与平台无关的 MoonBit 包，用于生成随机密码、PIN 和基于词库的
Passphrase。它是 AI Passport 固件所使用的可复用引擎，不是 ESP-IDF 或 FoloToy
接口的简单封装。

## 公共 API

- `PasswordPolicy` 提供类型化的兼容、标准、严格和自定义策略。
- `generate_password` 与 `generate_pin` 为应用代码返回普通 MoonBit `String`。
- `generate_password_into`、`generate_pin_into` 和
  `generate_passphrase_into` 写入调用方持有的 sink，适用于资源受限和嵌入式环境。
- 所有生成 API 都要求调用方传入 `next_u32 : () -> UInt`；库不会暗中使用弱随机源。

```moonbit
let policy = @securegen.PasswordPolicy::standard()
match @securegen.generate_password(policy, secure_random_u32) {
  Ok(secret) => use_secret(secret)
  Err(message) => report_error(message)
}
```

当前模块使用 Native checker 检查该包，并在 WasmGC 上实际运行测试。库代码不导入
固件、文件系统、网络、UI 或操作系统包。

## 应用

- `../examples/cli` 是独立的 MoonBit 消费者，用于证明该包可以脱离固件包导入。
  其中的确定性生成器只用于可复现演示，不能生成真实密码。
- 仓库根 MoonBit 包是供 FoloToy AI Passport 固件使用的 Native foreign-library
  适配器；现有 C ABI 已把生成工作委托给 `securegen`。

运行可移植包测试和示例：

```bash
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/securegen \
  --target wasm-gc --release --deny-warn
moon -C moonbit run examples/cli --target wasm-gc --release
```

## 安全边界

调用方负责随机熵质量、密码显示、存储、传输和清零。确定性回调适合测试，但不是安全
随机源。FoloToy 应用通过 C FFI 注入平台随机源，绝不会使用 CLI 示例的确定性随机源。
