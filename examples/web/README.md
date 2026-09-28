# Browser consumer

English | [简体中文](README.zh_CN.md)

This page is a real consumer of the publishable root module. DOM bindings and
`crypto.getRandomValues` are target adapters in `src/cmd/web`; password, PIN,
and passphrase generation remains in `moonbit-securegen`.

Build the MoonBit JavaScript target, then serve the repository root:

```bash
moon build --target js --release --deny-warn
python -m http.server 8000
```

Open <http://localhost:8000/examples/web/>. Opening `index.html` directly is
not recommended because browsers may restrict script and clipboard behavior on
`file:` URLs.

Run the web adapter's tests with:

```bash
moon test -p zhangsan2000w-art/moonbit-securegen/cmd/web --target js --release --deny-warn
node examples/web/smoke.mjs
```
