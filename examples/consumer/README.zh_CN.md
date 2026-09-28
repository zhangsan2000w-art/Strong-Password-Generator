# 独立 MoonBit 消费端

[English](README.md) | 简体中文

本模块与可发布的根模块彼此独立。它的 `moon.mod` 声明
`zhangsan2000w-art/moonbit-securegen@0.1.0`，与外部项目执行下列命令后的依赖形态
一致：

```bash
moon add zhangsan2000w-art/moonbit-securegen
```

开发时，仓库 workspace 会把该依赖解析到本地根模块。消费端只导入公开 API，并提供
跨模块集成门禁：

```bash
moon -C examples/consumer test --target wasm-gc --release --deny-warn
```

测试中的确定性随机源只用于复现。真实应用必须注入目标平台提供的密码学安全随机源。
