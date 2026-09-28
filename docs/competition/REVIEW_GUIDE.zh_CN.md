# 审查者指南：SecureGen for MoonBit

[English](REVIEW_GUIDE.md) | 简体中文

以下是无需先编译 FoloToy 固件、也无需持有硬件即可验证 MoonBit 工作的最短路径。

## 可复用产物是什么？

`moonbit/securegen` 是平台无关的 MoonBit 包，公共能力包括：

- 类型化 `PasswordPolicy` 预设和自定义策略；
- 返回 MoonBit `String` 的 `generate_password`、`generate_pin`；
- 面向嵌入式场景、由调用方持有输出 sink 的密码、PIN、Passphrase API；
- 无偏随机索引；
- 由调用方注入的 `() -> UInt` 随机熵接口。

该包不导入固件、UI、BLE、文件系统、网络或 ESP-IDF 代码。随机源采用注入式设计，
使不同消费端可以使用各自平台的密码学随机源，同时允许测试使用可复现序列。

## 哪些应用消费了这个包？

1. `moonbit/examples/cli` 是独立宿主应用，通过 `moonbitlang/core/env` 获取密码学
   随机熵，支持选择策略、自定义长度、PIN 和批量生成。
2. 仓库根 MoonBit 包是 FoloToy 固件适配器，保留设备 C ABI，但把密码、PIN 和
   Passphrase 生成委托给 `securegen`。

CLI 不导入固件适配包，可移植包也不导入任何一个应用。

## 无硬件验证

在仓库根目录运行：

```bash
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/securegen \
  --target wasm-gc --release --deny-warn
moon -C moonbit test -p folotoy/strong-password-generator-ai-passport/examples/cli \
  --target js --release --deny-warn
moon -C moonbit run examples/cli --target js --release -- \
  --profile strict --length 24 --count 3
python tools/check_repo.py
```

第一条验证可移植引擎，第二条验证应用参数与策略行为，第三条使用宿主密码学随机熵
跑通真实生成旅程，第四条检查仓库边界和 MoonBit 有效实现规模。

## 验证嵌入式消费端

激活 ESP-IDF 5.5.3 后运行：

```bash
./tools/validate.sh --firmware
```

固件门禁会从全新目录构建，分别编译可移植包和固件适配包，把两个 MoonBit core
链接为 C，构建 ESP32-C3 镜像，合并烧录文件，并检查偏移与分区边界。

## 证据边界

- 可移植引擎测试和 CLI 测试属于主机证据。
- ESP-IDF 构建与合并镜像检查通过属于构建证据。
- BLE 配对、重连、绑定持久化、屏幕交互和 HID 精确输入仍属于真机验收，不能从构建
  结果直接推导。
- 项目不会把确定性测试随机源描述成真实密码来源；CLI 与固件各自使用平台密码学
  随机源。
