# SecureGen

[English](README.md) | 简体中文

`securegen` 是一个与平台无关的 MoonBit 包，用于生成随机密码、PIN 和基于词库的
Passphrase。它是 AI Passport 固件所使用的可复用引擎，不是 ESP-IDF 或 FoloToy
接口的简单封装。

## 公共 API

- `PasswordPolicy` 提供类型化的兼容、标准、严格和自定义策略。
- `PassphrasePolicy` 与 `PassphraseSeparator` 把词库口令从仅供嵌入式调用的
  callback 接口提升为类型化应用 API。
- `generate_password`、`generate_pin` 与 `generate_passphrase` 为应用代码返回
  普通 MoonBit `String`。
- `generate_password_into`、`generate_pin_into` 和
  `generate_passphrase_into` 写入调用方持有的 sink，适用于资源受限和嵌入式环境。
- `RandomSource` 是类型化随机源边界；为可控内存分配与 C 兼容适配器保留 callback
  重载。
- `validate_password` 与 `validate_pin` 可校验生成或导入的凭据。
- 熵估算器以 0.1 bit 为单位返回结果，`Strength` 只负责把估算值映射为展示档位，
  不对调用方随机源的安全性做保证。

```moonbit
let policy = @securegen.PasswordPolicy::standard()
let random = @securegen.RandomSource::new(secure_random_u32)
match @securegen.generate_password_with_source(policy, random) {
  Ok(secret) => use_secret(secret)
  Err(message) => report_error(message)
}
```

密码长度支持 4～128 个字符，PIN 支持 4～32 位；平台适配层可以施加更窄的产品
限制。当前模块使用 Native checker 检查该包，并在 WasmGC 与 JavaScript 上执行可移植
测试。库代码不导入固件、文件系统、网络、UI 或操作系统包。

## 应用

- [`../../src/cmd/securegen`](../../src/cmd/securegen/main.mbt) 是独立的
  MoonBit 消费者，通过 `moonbitlang/core/env`
  获取密码学安全随机源，支持密码策略、自定义长度、PIN 和批量生成。
- `moonbit` workspace 成员是供 FoloToy AI Passport 固件使用的 Native foreign-library
  适配器；现有 C ABI 已把生成工作委托给 `securegen`。

运行可移植包测试和示例：

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon run src/cmd/securegen --target js --release -- --profile strict --length 24
```

## 安全边界

调用方负责随机熵质量、密码显示、存储、传输和清零。确定性回调适合测试，但不是安全
随机源。CLI 使用宿主环境提供的密码学随机源；FoloToy 应用通过 C FFI 注入平台随机源。
熵函数估算的是策略搜索空间，不会测量运行时随机质量、密码复用、在线限速或用户自选
模式的抵抗能力。
