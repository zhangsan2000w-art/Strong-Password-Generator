# 浏览器消费者示例

[English](README.md) | 简体中文

该页面真实依赖仓库根目录可发布模块。DOM 绑定与
`crypto.getRandomValues` 位于 `src/cmd/web` 目标适配层；密码、PIN、口令
的策略与生成逻辑仍由 `moonbit-securegen` 提供，没有复制到 JavaScript。

先构建 MoonBit JavaScript 目标，再从仓库根目录启动静态服务器：

```bash
moon build --target js --release --deny-warn
python -m http.server 8000
```

访问 <http://localhost:8000/examples/web/>。不建议直接双击 `index.html`，
因为浏览器可能限制 `file:` URL 下的脚本和剪贴板能力。

网页适配层测试命令：

```bash
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/web --target js --release --deny-warn
node examples/web/smoke.mjs
```
