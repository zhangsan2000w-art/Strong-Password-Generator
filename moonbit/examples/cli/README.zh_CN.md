# SecureGen CLI

[English](README.md) | 简体中文

这是基于可复用 `securegen` 包构建的独立 MoonBit 应用。它通过
`moonbitlang/core/env` 获取密码学安全随机字节，不依赖 ESP-IDF、FoloToy、
LVGL、BLE 或设备固件。

## 运行

```bash
moon -C moonbit run examples/cli --target js --release -- --help
moon -C moonbit run examples/cli --target js --release -- --profile strict --length 24
moon -C moonbit run examples/cli --target js --release -- --pin 8 --count 3
```

参数：

- `--profile compatible|standard|strict`：选择密码策略。
- `--length N`：把密码长度覆盖为 4～128。
- `--pin N`：改为生成 4～32 位十进制 PIN。
- `--count N`：一次输出 1～100 个相互独立的结果。

## 安全边界

如果宿主不能提供安全随机熵，应用不会悄悄降级到确定性随机源。生成结果会写入标准
输出，请避免终端录屏、共享日志以及复制包含密码的 Shell 输出。

生成算法仍然位于 `moonbit/securegen`；本目录只是消费端应用，也是其他 MoonBit
项目接入该库时可以参考的完整示例。
