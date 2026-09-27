// FAP_SCREENSHOT_V1 串口截屏服务（观测型，只读当前屏幕）。
// 需在 bsp_lvgl_init() 成功后调用一次 fap_screenshot_start()。
#pragma once

// 启动截屏监听任务：显式安装 USB-Serial-JTAG 驱动并监听主机命令
// FAP_SCREENSHOT_V1\n，命中后经 USB-CDC 回送满屏 RGB565 快照。
// 契约：只读屏幕，不重启、不改任何设置；任何失败都静默（主机侧表现为超时）。
// 内存契约：无 PSRAM 时满屏缓冲与 NimBLE 不能共存，捕获期间会临时挂起
// 蓝牙栈（bond 在 NVS 不受影响），蓝牙忙（配对/连接/输入中）时跳过捕获。
void fap_screenshot_start(void);
