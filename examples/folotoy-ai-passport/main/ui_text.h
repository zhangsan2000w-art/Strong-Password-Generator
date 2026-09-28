#pragma once

#include <stdint.h>

/*
 * 界面文案的落点：MoonBit 组装好的 UTF-8 字节经回调写进这里的共享缓冲
 * （见 moonbit/ui_text.mbt），C 侧只把 lv_label 指向这块缓冲。
 *
 * 文案种类必须与 moonbit/ui_text.mbt 的 ui_text_* 常量保持一致；
 * tools 无自动化检查，改一边就要改另一边。
 */
enum {
    UI_TEXT_PARAM_LABEL = 0,
    UI_TEXT_BATTERY = 1,
    UI_TEXT_BATTERY_UNAVAILABLE = 2,
    UI_TEXT_BLE_STATUS = 3,
    UI_TEXT_SEND_BUTTON = 4,
    UI_TEXT_RESULT_FAILURE = 5,
    UI_TEXT_RESULT_DONE = 6,
    UI_TEXT_RESULT_PLACEHOLDER = 7,
    UI_TEXT_ENTROPY = 8,
    UI_TEXT_GENERATE_BUTTON = 9,
    UI_TEXT_SETTINGS_NAME = 10,
    UI_TEXT_SETTINGS_VALUE = 11,
    UI_TEXT_SETTINGS_HINT = 12,
    UI_TEXT_DIAGNOSTIC_STATUS = 13,
    UI_TEXT_DIAGNOSTIC_PROGRESS = 14,
};

/* MoonBit 报的字节数与实际落进缓冲的长度一致时返回缓冲指针，
 * 否则返回 NULL（调用方保留上一帧，避免显示半截句子）。 */
const char *ui_text_collected(int32_t built_bytes);

/* 空返回值表示本次构建失败；调用方须跳过这一帧。 */
const char *ui_text(int kind, int a, int b);
const char *ui_text_diagnostic_detail(int status, int completed, int target,
                                      int passed, int failure);
