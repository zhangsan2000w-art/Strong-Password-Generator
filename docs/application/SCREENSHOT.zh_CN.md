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

- `examples/folotoy-ai-passport/moonbit/screenshot.mbt` 承载协议核心与捕获会话，由 `moon test` 覆盖：命令匹配
  状态机（与"滑动窗口 + 行结束符复位"语义等价）、应答协议头构建、以及
  校验每条带的带序状态机（顺序、横向铺满、紧凑排布、不越面板边界）、决定一次捕获何时算完成的整帧记账、故障词汇表，以及条带字节序策略。C 适配层只传整数、报告事件，并通过两个
  `passport_screenshot_header_*` 与 `passport_screenshot_name_*` 回调收回字节。
- `examples/folotoy-ai-passport/main/fap_screenshot.c` 只承载平台边界，不含任何判定：显式安装 USB-Serial-JTAG 驱动
  （RX 256 字节、TX 1024 字节）、低于 LVGL 的优先级 3 读取任务、面板
  `draw_bitmap` 抽头、双槽条带环形缓冲、按 TX 环形缓冲定标的 512 字节
  分块流式发送、挂/解捕获时的 LVGL 锁次序，以及二进制窗口内的日志静音。

为什么按条带而不是一次整屏：本板无 PSRAM，内部 RAM 被切成 118,848 字节的
常规堆区与另一个 116,496 字节的 retention 区，单次分配不能跨区，所以
153,600 字节的整屏缓冲无论空闲多少都拿不到——实测挂起蓝牙栈后内部空闲堆
有 183,652 字节，最大连续块却只有 106,496。蓝牙键盘本身还要占约 115KB，
"整屏一次成型"与"蓝牙在线"在算术上互斥。于是捕获改走 LVGL 的部分刷新：
显示驱动在 flush 时本来就持有一条 240x20 的条带，抽头逐条把它拷出来（并
把 `esp_lvgl_port` 为 SPI 面板做的大端字节序换回小端），送入只在捕获期
存在、结束立刻释放的 18.75KB 环形缓冲。主机端看到的字节流与原来完全一致，
而蓝牙栈全程不需要挂起。

为什么“完成判定”要留在 MoonBit：抽头（生产者，LVGL 任务）与串口写出（消费者）各自推进一个计数器，双槽下抽头会跑在发送任务前面。用“已产出字节数”判完成，会在最后一条带还没发出去时就报成功，静默把图截短。这条规则因此由宿主机单测钉住，而不是写在 C 的循环里。

- `tools/screenshot.py` 是主机端抓取/转换工具；其纯函数由
  `tests/test_screenshot_convert.py` 覆盖。

## 边界

- 截屏只读、观测型。不触碰密码应用状态，也不会触发 BLE、音频或存储。
- 日志与二进制应答共用同一路 USB-CDC；固件在应答窗口内静音日志，因此
  截屏字节只能通过协议客户端读取（普通终端转储不可靠）。
- 电量、主题与屏幕内容按实际显示截取；没有合成画面或离屏渲染。
- 挂上捕获会强制整屏失效重绘，所以读取期间屏幕会明显重画一次；主机取数
  慢于设备产出时，LVGL 任务会在抽头里阻塞。因此得到的是连续一致的一帧，
  不是叠加中的实况；主机拔线或过慢会以故障结束捕获，而不是卡死。
