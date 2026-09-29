# SecureGen for MoonBit

[English](APPLICATION.md) | 简体中文

一页申报材料。审查走查见 [REVIEW_GUIDE.zh_CN.md](REVIEW_GUIDE.zh_CN.md)，AI 协助
披露见 [AI_USAGE.zh_CN.md](../application/AI_USAGE.zh_CN.md)。

## 申报对象

`zhangsan2000w-art/moonbit-securegen` 是一个可发布、可复用的 MoonBit 凭据生成与安全
策略库。它不是固件应用，申报入口也不是设备 demo。边界是
[`moon.mod`](../../moon.mod) 声明的仓库根 MoonBit 模块，版本 `0.1.1`，公开面是平台
无关的根包 [`src`](../../src/api.mbt)。消费端 `moon add
zhangsan2000w-art/moonbit-securegen` 即可使用，不需要 ESP-IDF、LVGL、BLE、NVS、文件
系统、网络或任何 FoloToy 代码。

## 库提供什么

| 能力 | 公开接口 |
| --- | --- |
| 类型化密码策略 | `PasswordPolicy::{new, compatible, standard, strict}`、`with_length`、`is_valid` |
| 类型化 Passphrase 策略 | `PassphrasePolicy::{new, standard}`、`word_count`、`PassphraseSeparator::{hyphen, period, underscore}` |
| 随机源抽象 | `RandomSource::new(() -> UInt)`；所有生成函数也接受裸 `() -> UInt` |
| 密码、Passphrase、PIN | `generate_password`、`generate_passphrase`、`generate_pin` 及 `*_with_source` 变体，返回 `Result[String, String]` |
| 受控内存的嵌入式 API | `generate_password_into`、`generate_pin_into`、`generate_passphrase_into`、`generate_password_compat`，输出 sink 由调用方持有（`emit : (Int) -> Bool`） |
| 输出校验 | `validate_password`、`validate_pin` |
| 熵估算与强度档位 | `PasswordPolicy::estimated_entropy_bits_x10`、`estimate_pin_entropy_bits_x10`、`estimate_passphrase_entropy_bits_x10`、`Strength`、`strength_from_entropy_x10` |
| 无偏索引选择 | `unbiased_index` 拒绝采样 |

根包只导入 `moonbitlang/core/debug`（白盒测试另有 `core/test`），见
[`src/moon.pkg`](../../src/moon.pkg)。`src` 中除 `src/cmd` 外没有任何 `extern`
声明、C FFI 或平台绑定。随机数刻意采用注入式设计：各目标平台提供自己的密码学随机源，
测试则使用可复现序列。库不会把确定性测试随机源描述成真实密码来源。

## 目标平台与消费端

`supported_targets = "all"`、`preferred_target = "wasm-gc"`，同一套引擎可运行在
Native、WasmGC 与 JavaScript 上。四个互相独立的消费端证明这一点：

1. [`src/cmd/securegen`](../../src/cmd/securegen/main.mbt) —— 独立命令行宿主应用，
   通过 `moonbitlang/core/env` 获取密码学随机熵。
2. [`src/cmd/web`](../../src/cmd/web/main.mbt) 加
   [`examples/web`](../../examples/web/README.md) —— 浏览器消费端，只有 DOM 与
   `crypto` 绑定属于目标适配层。
3. [`examples/consumer`](../../examples/consumer/README.md) —— 声明版本化库依赖的
   独立 MoonBit 模块，只使用公开 API。
4. [`examples/folotoy-ai-passport/moonbit`](../../examples/folotoy-ai-passport/moonbit)
   —— 下一节说明的嵌入式适配器。

## FoloToy 只是一个嵌入式示例

`examples/folotoy-ai-passport` 存放上游本已存在的 FoloToy AI Passport 固件。它留在
仓库里的目的，是证明受控内存 API 在真实 ESP32-C3（8 MB Flash、无 PSRAM）上可用：
C 侧继续承担 BSP、LVGL、NimBLE 传输、NVS、编解码器等硬件胶水，所有凭据决策都委托给
`securegen`。删除该目录后，库、CLI、浏览器页面与 consumer 模块依然完整可用、可测试；
`python tools/check_repo.py` 与 `REVIEW_GUIDE.md` 中的命令正是在无硬件条件下完成验证。

## 本机实测数据

| 指标 | 数值 | 复核方式 |
| --- | --- | --- |
| 有效生产 MoonBit 行数 | 3,632（根库 775 + 适配层 2,857），门禁下限 1,000 | `python tools/check_repo.py` |
| 物理生产 `.mbt` 行数 | 4,883 | 对 `tools/check_repo.py` 中 `moonbit_product_lines()` 扫描的同一文件集合统计原始行数 |
| MoonBit 测试与应用行数 | 2,722（46 个受版本管理的 MoonBit 文件合计 7,605 行） | 同一口径，计入测试与应用 |
| MoonBit 测试 | 122 项全部通过：根库 12、CLI 3、浏览器 2、consumer 2、适配层 103 | `REVIEW_GUIDE.md` 中按包的 `moon test` 命令 |
| Python 主机测试 | 21 项全部通过：固件布局 11、截屏转换 7、编译器门禁 3 | `python tests/test_verify_firmware.py` 等 |
| 提交数 | 42 次，日期均在 2026-08-07 至 2026-09-29 | 在 `8b4e466` 上执行 `git rev-list --count HEAD` |

## 主张逐项核对

| 申报要求 | 状态 | 证据或说明 |
| --- | --- | --- |
| MoonBit 项目身份 | 已核实 | 根模块就是 MoonBit 库；`tools/check_repo.py` 在生产有效行数低于 1,000 时直接判失败。 |
| 有效 MoonBit 超过 1,000 行 | 已核实 | 本机 `python tools/check_repo.py` 报告 3,632 行。 |
| 赛期提交与可用 MVP | 已核实数量与日期，窗口未核对 | 42 次提交，日期跨度 2026-08-07 至 2026-09-29；MoonBit 库、CLI 与浏览器页面构成的 MVP 按 `REVIEW_GUIDE.md` 的命令无需硬件即可运行。这些日期是否落在主办方的赛期窗口内，属于维护者需要自行确认的事项，不是仓库可自证的事实。 |
| 根库不依赖 C FFI、BLE、LVGL、NVS | 已核实 | `src/moon.pkg` 仅导入 `moonbitlang/core/debug` 与测试用 `core/test`；`src/api.mbt`、`src/typed_api.mbt` 无 `extern`。 |
| Mooncakes 0.1.1 | 已核实 | 在全新 scratch 模块中执行 `moon add zhangsan2000w-art/moonbit-securegen`，本机已从注册中心解析并下载 `0.1.1`。缓存产物内含 `moon.mod`（`version = "0.1.1"`）、`src/api.mbt`、`src/typed_api.mbt`、`src/moon.pkg`、两个命令包、consumer 与浏览器示例以及 `LICENSE`，不含固件、tools 或 workflow 文件。[`VERSIONING.zh_CN.md`](../api/VERSIONING.zh_CN.md) 定义发布约定。 |
| Native、Wasm、CLI、Web、consumer、测试与 CI | 已核实 | `./tools/validate.sh --static` 现已完整通过：仓库检查、`moonc >= 0.10.14` 门禁、五个 MoonBit 套件（`--deny-warn`）、CLI 实跑生成、浏览器 smoke、发布包边界检查、actionlint 以及 21 项 Python 主机测试。前提是编译器不低于 `moonc 0.10.14`；官方 `latest` 安装包即满足，CI 也通过 [`static-checks.yml`](../../.github/workflows/static-checks.yml) 每次安装该版本。 |
| ESP-IDF 固件构建 | 已核实 | 在 ESP-IDF 5.5.3 + `moonc 0.10.14` 下，`./tools/validate.sh --firmware` 从全新构建目录跑通：可移植包与固件适配包生成 C、链接进 ESP32-C3 应用，并校验合并后的烧录镜像（bootloader 21,024 字节 @`0x0`、分区表 3,072 字节 @`0x8000`、应用 1,137,680 字节位于 `0x10000` 处 8,323,072 字节的 `factory` 分区内、合并镜像 1,203,216 字节）。 |
| 真机验收 | 未验证 | BLE 配对与键盘输入、显示、字体、按键、电池与持久化仍属真机检查；构建通过不等于设备通过。 |

## 来源、移植与许可证

项目自有代码为 MIT。下表中的其它组件要么承自上游，要么在构建时拉取，且每一项都能在
本仓库内找到对应声明。

| 组件 | 来源 | 许可证 | 仓库内声明 |
| --- | --- | --- | --- |
| MoonBit 库、CLI、浏览器页面、consumer 模块、适配层逻辑、测试、文档 | 本项目自行编写，AI 协助情况见 [AI_USAGE.zh_CN.md](../application/AI_USAGE.zh_CN.md) | MIT | [`LICENSE`](../../LICENSE) |
| FoloToy AI Passport 固件、BSP、组件、硬件文档 | 上游 `FoloToy/ai-passport`（Gitee 与 GitHub），由提交 `5f19183` 原样迁移到 `examples/folotoy-ai-passport` | MIT | 保留的 [`LICENSE`](../../LICENSE)，其中仍写明 `Copyright (c) 2026 FoloToy`，另见根 README 的上游说明 |
| EFF Short Wordlist for Passphrases #1，共 1,296 条 | 电子前哨基金会 EFF | CC BY 3.0 US | 原文收录于 [`assets/wordlists/eff-short-wordlist-1.txt`](../../assets/wordlists/eff-short-wordlist-1.txt)，根 README 记录其 SHA-256 `8f5ca830b8bffb6fe39c9736c024a00a6a6411adb3f83a9be8bfeeb6e067ae69`，并由 `tools/generate_wordlist.py` 展开为 Flash 常量表 |
| Noto Sans SC | Google | SIL Open Font License 1.1 | 声明收录于 [`assets/fonts/NotoSansSC-OFL.txt`](../../assets/fonts/NotoSansSC-OFL.txt)；派生的 LVGL 字模 `examples/folotoy-ai-passport/main/passport_font_zh_16.c` 已在 [`.gitattributes`](../../.gitattributes) 中标记为生成物 |
| MoonBit native runtime 的 C 头文件与 `runtime.c` | 随 MoonBit 工具链分发的 native runtime，为 ESP-IDF 构建而内嵌 | Apache-2.0 | [`examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt`](../../examples/folotoy-ai-passport/components/moonbit_password/RUNTIME_LICENSE.txt)，`runtime/` 目录在 [`.gitattributes`](../../.gitattributes) 中标记为 vendored |
| LVGL 与 4 个 Espressif 组件 | ESP-IDF 组件管理器，在构建时解析 | LVGL 为 MIT；Espressif 组件为 Apache-2.0 | 不入库：`managed_components/` 已被 [`.gitignore`](../../.gitignore) 忽略，每次构建都会重新拉取并自带许可证文件 |

产品逻辑从 C 迁移到 MoonBit 的提交为：`bda1591`（可复用生成引擎）、`115be24` 与
`b14c669`（其余界面文案、最后一块仅测试用途的逻辑）、`d29460c`（类型化凭据
API）。C 侧目前只保留 BSP 与 ESP-IDF 初始化、LVGL 控件调用、NimBLE 传输、NVS 访问、
编解码器写入以及平台随机数源。

## 主张边界

本文件只描述 `Strong-Password-Generator_AI-Passport` 仓库。它不代表、不吸收、也不
替代 `ai-passport-codex-buddy` 的独立评审结论；那个报名有它自己的历史与驳回理由。
项目自有代码采用 MIT，上游与第三方声明见上表以及根目录 [LICENSE](../../LICENSE)。
