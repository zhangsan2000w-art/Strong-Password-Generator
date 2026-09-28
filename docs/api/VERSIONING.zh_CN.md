# 版本约定与 Mooncakes 发布

[English](VERSIONING.md) | 简体中文

`zhangsan2000w-art/moonbit-securegen` 遵循语义化版本。根目录 `moon.mod`
中的版本是库版本的唯一事实来源，也是发布到 Mooncakes 的版本。

## 兼容性约定

- **补丁版本**（`0.1.1`）用于修复行为或文档，不应主动改变公开签名或
  合法输出约定。
- **次版本**（`0.2.0`）可以增加 API。项目低于 `1.0.0` 时，次版本也可以
  删除或改变实验性 API，但发布说明必须明确标出，并提供迁移示例。
- **主版本**（`1.0.0`）稳定后，任何不兼容的公开 API 或行为约定变化都
  必须提升主版本。
- `src` 是公开库边界；`src/cmd/*` 与 `examples/*` 是消费者和适配层，
  它们的界面或命令行变化本身不构成库 API 破坏。
- 库支持 Native、WasmGC 与 JavaScript。每次发布必须保证 WasmGC、
  JavaScript 的可移植库测试通过，并保证 Native 代码生成通过。

条件允许时，弃用 API 至少保留一个次版本。安全修复可能要求更快移除，
此时发布说明必须写清风险与替代方案。

## 发布清单

1. 同步更新 `moon.mod` 与 `examples/consumer/moon.mod` 中的版本化依赖。
2. 在双语变更记录中写入面向用户的库变更与迁移说明。
3. 在 Linux 或等价环境运行 `./tools/validate.sh --static`。
4. 检查 `moon package --list`；固件、C FFI、BLE、LVGL、NVS、工具、CI
   和构建产物不得成为核心库依赖或发布包内容。
5. 运行 `moon publish --dry-run` 并检查生成包，再使用拥有相应模块命名
   空间的 Mooncakes 账号执行 `moon publish`。
6. 用全新项目执行 `moon add zhangsan2000w-art/moonbit-securegen`，并确认
   consumer 集成测试通过。

已发布版本不可变。发布失败或不完整时不得复用版本号；修复后应提升版本。
