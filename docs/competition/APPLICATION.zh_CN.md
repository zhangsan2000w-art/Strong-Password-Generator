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
| 赛期提交与可用 MVP | 已核实 | 42 次提交；MVP 即库加 CLI 与浏览器页面，按 `REVIEW_GUIDE.md` 命令无需硬件即可运行。 |
| 根库不依赖 C FFI、BLE、LVGL、NVS | 已核实 | `src/moon.pkg` 仅导入 `moonbitlang/core/debug` 与测试用 `core/test`；`src/api.mbt`、`src/typed_api.mbt` 无 `extern`。 |
| Mooncakes 0.1.1 | 部分核实 | `moon.mod` 声明 `0.1.1`，[`VERSIONING.zh_CN.md`](../api/VERSIONING.zh_CN.md) 定义发布约定；本次未查询注册中心，发布是维护者的手工动作。 |
| Native、Wasm、CLI、Web、consumer、测试与 CI | 已按运行核实，但有一个工具链前提 | 五个套件本机全部通过。`./tools/validate.sh --static` 在本机会中止，因为已安装的 `moonc` 为 0.10.12，而门槛要求 0.10.14；该门槛由 [`static-checks.yml`](../../.github/workflows/static-checks.yml) 在 CI 强制执行。提交前请先升级本机工具链再复跑。 |
| ESP-IDF 固件构建 | 本次未重跑 | 需要激活 ESP-IDF 5.5.3，执行 `./tools/validate.sh --firmware`。 |
| 真机验收 | 未验证 | BLE 配对与键盘输入、显示、字体、按键、电池与持久化仍属真机检查；构建通过不等于设备通过。 |

## 主张边界

本文件只描述 `Strong-Password-Generator_AI-Passport` 仓库。它不代表、不吸收、也不
替代 `ai-passport-codex-buddy` 的独立评审结论；那个报名有它自己的历史与驳回理由。
项目自有代码采用 MIT，上游与第三方声明见本文下一节以及根目录
[LICENSE](../../LICENSE)。
