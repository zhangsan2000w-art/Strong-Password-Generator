# 审查者指南：SecureGen for MoonBit

[English](REVIEW_GUIDE.md) | 简体中文

以下是无需先编译 FoloToy 固件、也无需持有硬件即可验证 MoonBit 工作的最短路径。

## 验收证据

| 要求 | 仓库证据 |
| --- | --- |
| MoonBit 主体，`moonc >= 0.10.14` | 根库与产品策略由 MoonBit 实现；`tools/check_moonc_version.py` 是静态检查与 CI 的硬门禁；生成字体 C 与上游 runtime 通过 `.gitattributes` 明确标识。 |
| 公开仓库与提交记录 | GitHub 仓库公开，并保留聚焦的 Conventional Commit 历史。 |
| 清晰源码与可用核心 | `src` 是可移植库，适配器和应用位于 `src/cmd` 与 `examples`。 |
| README 可复现 | 根 README 提供目标、`moon add` 安装、包导入、CLI 命令、浏览器说明与 consumer 链接。 |
| CI 检查／构建／测试 | `static-checks.yml` 与 `firmware-checks.yml` 调用共享的 `tools/validate.sh` 门禁。 |
| 可运行示例 | 包含 CLI、浏览器、独立模块 consumer 和 FoloToy 固件示例。 |
| 核心测试 | 122 项 MoonBit 测试（可移植根库 12、CLI 3、浏览器命令 2、独立模块消费者 2、固件适配层 103）及 21 项 Python 主机测试覆盖生成、校验、熵、消费者、适配器与固件布局。 |
| MoonBit 实现规模 | `python tools/check_repo.py` 报告有效生产 MoonBit 3,632 行（根库 775 + 固件适配层 2,857），下限为 1,000 行；物理生产 `.mbt` 为 4,883 行。 |
| Mooncakes | `zhangsan2000w-art/moonbit-securegen@0.1.1` 可通过 `moon add` 安装。 |
| OSI 许可证与署名 | 根代码使用 MIT；保留 FoloToy 上游 MIT 声明，并记录 EFF 词库、Noto Sans SC 与 MoonBit runtime 的许可证。 |

## 可复用产物是什么？

仓库根目录是可发布的 `zhangsan2000w-art/moonbit-securegen` 模块，`src` 是它的
平台无关根包，公共能力包括：

- 类型化密码策略与 Passphrase 策略；
- 返回 MoonBit `String` 的密码、Passphrase 与 PIN API；
- 类型化 `RandomSource`、公开校验、熵估算与强度档位；
- 面向嵌入式场景、由调用方持有输出 sink 的密码、PIN、Passphrase API；
- 无偏随机索引；
- 由调用方注入的 `() -> UInt` 随机熵接口。

该包不导入固件、UI、BLE、文件系统、网络或 ESP-IDF 代码。随机源采用注入式设计，
使不同消费端可以使用各自平台的密码学随机源，同时允许测试使用可复现序列。

## 哪些应用消费了这个包？

1. `src/cmd/securegen` 是独立宿主应用，通过 `moonbitlang/core/env` 获取密码学
   随机熵，支持选择策略、自定义长度、PIN 和批量生成。
2. `src/cmd/web` 与 `examples/web` 构成浏览器消费者；DOM 与安全随机数绑定属于
   目标适配层，凭据逻辑仍留在核心库。
3. `examples/consumer` 是声明版本化库依赖的独立模块，只通过公开 API 做跨包测试。
4. `examples/folotoy-ai-passport/moonbit` 是 FoloToy 固件适配器，保留设备 C ABI，但把密码、PIN 和
   Passphrase 生成委托给 `securegen`。

CLI 不导入固件适配包，可移植包也不导入任何一个应用。

## 无硬件验证

在仓库根目录运行：

```bash
moon test -p zhangsan2000w-art/moonbit-securegen \
  --target wasm-gc --release --deny-warn
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/securegen \
  --target js --release --deny-warn
moon -C examples/consumer test --target wasm-gc --release --deny-warn
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/web \
  --target js --release --deny-warn
moon build --target js --release --deny-warn
node examples/web/smoke.mjs
moon run src/cmd/securegen --target js --release -- \
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
