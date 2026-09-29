// FAP_SCREENSHOT_V1 串口截屏服务（观测型，只读当前屏幕）。
// 需在 bsp_lvgl_init() 成功后调用一次 fap_screenshot_start()。
#pragma once

#include <stdbool.h>
#include <stdint.h>

// 启动截屏监听任务：显式安装 USB-Serial-JTAG 驱动并监听主机命令
// FAP_SCREENSHOT_V1\n，命中后经 USB-CDC 回送满屏 RGB565LE 快照。
// 契约：只读屏幕，不重启、不改任何设置；任何失败都静默（主机侧表现为超时）。
//
// 内存契约：本板无 PSRAM，内部 RAM 分成 118,848 字节的常规堆区与另一个
// 116,496 字节的 retention 区，单次分配不能跨区，所以 153,600 字节的整屏
// 缓冲拿不到（实测挂起蓝牙后最大连续块仅 106,496）。快照因此改走条带流：
// 抽头在面板 draw_bitmap 处逐条取走 LVGL 部分刷新的 240x20 条带，经一个
// 只在捕获期存在的 18.75KB 双槽环发送。蓝牙栈全程不挂起，也不因"蓝牙忙"
// 拒绝捕获；线上字节流与整屏缓冲时逐字节一致，主机端无需改动。
//
// 判定与记账（带序、几何、完成条件、故障归因、字节序策略）都在
// moonbit/screenshot.mbt；本文件只做等待、搬运与硬件时序。
void fap_screenshot_start(void);

// MoonBit 侧经回调把协议头与结果名写回 C：协议头进 s_header，结果名进
// s_result_name。两者都由对应的 *_build 函数在静音窗口外调用。
void passport_screenshot_header_reset(void);
int32_t passport_screenshot_header_push(int32_t ch);
void passport_screenshot_name_reset(void);
int32_t passport_screenshot_name_push(int32_t ch);
