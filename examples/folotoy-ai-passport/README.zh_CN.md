# FoloToy AI Passport 适配示例

[English](README.md) | 简体中文

本目录是一套真实可构建的 ESP32-C3 应用，消费仓库根目录的
`zhangsan2000w-art/moonbit-securegen` 库。它演示嵌入式适配层如何注入硬件随机数，
并把生成结果接入 FoloToy 的显示、按键、音频、持久化与 BLE HID 服务。

可复用库不依赖本目录中的任何内容。ESP-IDF、LVGL、NimBLE、NVS、C FFI 声明、
Flash 词库适配和随固件编译的 MoonBit runtime 都留在此应用边界之后。

## 构建

在仓库根目录激活 ESP-IDF 5.5.3，然后运行：

```bash
./tools/validate.sh --firmware
```

如需在本目录执行增量构建：

```bash
idf.py set-target esp32c3
idf.py build
```

构建通过不等于真机验收。BLE 配对、重连、绑定持久化、HID 精确输入、按键、显示、
音频、NVS、电池读数与硬件 RNG 适配器仍需上板验证。
