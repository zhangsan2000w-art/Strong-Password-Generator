# FAP_SCREENSHOT_V1 串口截屏

[English](SCREENSHOT.md) | 简体中文

`FAP_SCREENSHOT_V1` 是一个观测型串口协议，用于在电脑上截取设备屏幕。主机经
USB-CDC 发送一条 ASCII 命令，固件应答一行协议头加一段紧凑排布的小端 RGB565
像素。该命令不会重启、烧录或修改任何设置；任何失败设备都保持静默，主机侧
表现为超时。

实现遵循
[`docs/reference/y2lin/serial-screenshot-protocol.zh_CN.md`](../reference/y2lin/serial-screenshot-protocol.zh_CN.md)
中记录的全部坑点。

## 电脑端用法

```bash
python tools/screenshot.py --list-ports
python tools/screenshot.py --port COM5 --output screen.png
# 不接设备，把已有的 RGB565LE 转储转成 PNG：
python tools/screenshot.py --raw dump.bin --width 240 --height 320 --output screen.png
```

串口抓取需要 `pyserial`；raw 转换仅依赖标准库。脚本输出 8 位 RGB PNG。设备
需运行包含本功能的固件（插上 USB 线，端口枚举为 USB 串口/JTAG 设备）。

## 协议

```text
主机 -> 设备: "FAP_SCREENSHOT_V1\n"               （ASCII，滑动窗口匹配）
设备 -> 主机:  "FAP_SCREENSHOT_V1 <w> <h> RGB565LE <bytes>\n"
设备 -> 主机:  <bytes> 小端 RGB565 像素，紧凑排布，按行优先
```

在本板上应答恒为 `FAP_SCREENSHOT_V1 240 320 RGB565LE 153600\n` 加 153,600 个
像素字节。

## 架构分工

- `examples/folotoy-ai-passport/moonbit/screenshot.mbt` 承载协议核心，由 `moon test` 覆盖：命令匹配
  状态机（与"滑动窗口 + 行结束符复位"语义等价）、应答协议头构建、快照
  几何校验。C 适配层只传整数，并通过两个 `passport_screenshot_header_*`
  回调收回字节。
- `examples/folotoy-ai-passport/main/fap_screenshot.c` 承载平台边界：显式安装 USB-Serial-JTAG 驱动
  （RX 256 字节、TX 1024 字节）、低于 LVGL 的优先级 3 读取任务、静态
  64 字节对齐的满屏快照缓冲（在 `bsp_lvgl_lock()` 下用
  `lv_snapshot_take_to_draw_buf()` 渲染）、按 TX 环形缓冲定标的 512 字节
  分块流式发送，以及二进制窗口内的日志静音。
- `tools/screenshot.py` 是主机端抓取/转换工具；其纯函数由
  `tests/test_screenshot_convert.py` 覆盖。

## 边界

- 截屏只读、观测型。不触碰密码应用状态，也不会触发 BLE、音频或存储。
- 日志与二进制应答共用同一路 USB-CDC；固件在应答窗口内静音日志，因此
  截屏字节只能通过协议客户端读取（普通终端转储不可靠）。
- 电量、主题与屏幕内容按实际显示截取；没有合成画面或离屏渲染。
