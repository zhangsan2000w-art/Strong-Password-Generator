#include "fap_screenshot.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "bsp_display.h"
#include "bsp_pins.h"
#include "driver/usb_serial_jtag.h"
#include "driver/usb_serial_jtag_vfs.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "moonbit_password.h"
#include "password_ble_keyboard.h"

#define TAG "fap_screenshot"

// LVGL 任务优先级为 4：串口辅助任务必须低于它，避免饿死渲染。
#define SCREENSHOT_TASK_PRIORITY 3
// 满屏软件渲染需要的栈余量（参考实现实测 8192 舒适）。
#define SCREENSHOT_TASK_STACK 8192

// 单次写入不得超过 TX 环形缓冲（1024），按 512 字节分块流式发送。
#define SCREENSHOT_TX_CHUNK 512
#define SCREENSHOT_RX_BUFFER 256
#define SCREENSHOT_TX_BUFFER 1024
#define SCREENSHOT_RETRY_MS 200
#define SCREENSHOT_WRITE_TIMEOUT_MS 2000
#define SCREENSHOT_LVGL_LOCK_TIMEOUT_MS 1000

// MoonBit 协议头最长约 40 字节；留出裕量，越界由 push 回调拒绝。
#define SCREENSHOT_HEADER_MAX 64

// 无 PSRAM：满屏 RGB565 缓冲（150KB）与 NimBLE（约 115KB）不能同时驻留
// 内部 RAM。每次捕获先挂起蓝牙栈让出内存，捕获后立即释放并恢复蓝牙；
// 配对 bond 保存在 NVS，恢复后自动重新广播。蓝牙忙（配对/连接/输入中）
// 时拒绝捕获，宁可静默也不打断用户。
static TaskHandle_t s_task_handle;

// MoonBit 协议头字节经回调落入此缓冲（passport_moonbit_screenshot_header_build）。
static uint8_t s_header[SCREENSHOT_HEADER_MAX];
static size_t s_header_len;

void passport_screenshot_header_reset(void)
{
    s_header_len = 0;
}

int32_t passport_screenshot_header_push(int32_t ch)
{
    if (ch < 0 || ch > 0xFF || s_header_len >= SCREENSHOT_HEADER_MAX) {
        return 0;
    }
    s_header[s_header_len++] = (uint8_t)ch;
    return 1;
}

static bool render_snapshot(uint8_t *pixels)
{
    // stride 显式取 width*2，保证紧凑排布（本板 LV_DRAW_BUF_STRIDE_ALIGN=1）。
    lv_draw_buf_t snapshot;
    (void)lv_draw_buf_init(
        &snapshot,
        BSP_LCD_W,
        BSP_LCD_H,
        LV_COLOR_FORMAT_RGB565,
        BSP_LCD_W * 2,
        pixels,
        BSP_LCD_W * BSP_LCD_H * 2
    );
    // LVGL 非线程安全：只在渲染瞬间持锁，传输期间 UI 照常刷新。
    if (!bsp_lvgl_lock(SCREENSHOT_LVGL_LOCK_TIMEOUT_MS)) {
        ESP_LOGW(TAG, "LVGL lock timeout; screenshot skipped");
        return false;
    }
    lv_result_t result = lv_snapshot_take_to_draw_buf(
        lv_screen_active(), LV_COLOR_FORMAT_RGB565, &snapshot);
    bsp_lvgl_unlock();
    if (result != LV_RESULT_OK) {
        ESP_LOGW(TAG, "lv_snapshot_take_to_draw_buf failed");
        return false;
    }
    // 几何校验逻辑在 MoonBit（moonbit/screenshot.mbt）：只放行
    // 与 BSP 面板一致的紧凑满屏 RGB565；不符宁可不发（失败要静默）。
    if (passport_moonbit_screenshot_geometry_ok(
            (int32_t)snapshot.header.w,
            (int32_t)snapshot.header.h,
            (int32_t)snapshot.header.stride,
            (int32_t)snapshot.data_size,
            BSP_LCD_W,
            BSP_LCD_H) != 1) {
        ESP_LOGW(TAG, "unexpected snapshot geometry; reply suppressed");
        return false;
    }
    return true;
}

// 分块阻塞写入；块失败（如主机拔出）放弃本次传输，但任务继续存活。
static bool write_chunked(const uint8_t *data, size_t len)
{
    size_t offset = 0;
    while (offset < len) {
        size_t chunk = len - offset;
        if (chunk > SCREENSHOT_TX_CHUNK) chunk = SCREENSHOT_TX_CHUNK;
        int written = usb_serial_jtag_write_bytes(
            data + offset, chunk, pdMS_TO_TICKS(SCREENSHOT_WRITE_TIMEOUT_MS));
        if (written < 0 || (size_t)written != chunk) return false;
        offset += (size_t)written;
    }
    return true;
}

static void send_reply(void)
{
    // 静音窗口覆盖整个捕获期：挂起/恢复蓝牙本身也会打日志，日志与应答
    // 共用同一路 USB-CDC，混入一个字节整幅图就错位。
    esp_log_level_set("*", ESP_LOG_NONE);

    if (!password_ble_keyboard_stack_suspend()) {
        esp_log_level_set("*", CONFIG_LOG_DEFAULT_LEVEL);
        ESP_LOGW(TAG, "BLE busy; screenshot skipped");
        return;
    }

    uint8_t *pixels = heap_caps_malloc(
        BSP_LCD_W * BSP_LCD_H * 2, MALLOC_CAP_8BIT | MALLOC_CAP_INTERNAL);
    if (pixels == NULL) {
        password_ble_keyboard_stack_resume();
        esp_log_level_set("*", CONFIG_LOG_DEFAULT_LEVEL);
        ESP_LOGW(TAG, "snapshot buffer unavailable; capture skipped");
        return;
    }

    const uint32_t payload = BSP_LCD_W * BSP_LCD_H * 2;
    const int32_t header_len = passport_moonbit_screenshot_header_build(
        BSP_LCD_W, BSP_LCD_H, (int32_t)payload);
    bool ok = header_len > 0 && (size_t)header_len == s_header_len;
    if (!ok) {
        ESP_LOGW(TAG, "protocol header build failed");
    } else {
        ok = render_snapshot(pixels);
    }

    if (ok) {
        ok = write_chunked(s_header, s_header_len) &&
             write_chunked(pixels, payload);
        (void)usb_serial_jtag_wait_tx_done(
            pdMS_TO_TICKS(SCREENSHOT_WRITE_TIMEOUT_MS));
        if (!ok) {
            ESP_LOGW(TAG, "host disconnected during transfer; reply abandoned");
        }
    }

    free(pixels);
    password_ble_keyboard_stack_resume();
    esp_log_level_set("*", CONFIG_LOG_DEFAULT_LEVEL);
    /* 恢复后统一补诊断日志：窗口内全静音，主机端重同步会跳过它。 */
    uint32_t profile[5];
    password_ble_keyboard_suspend_profile(profile);
    ESP_LOGI(
        TAG,
        "capture ok=%d heap stages=%lu/%lu/%lu/%lu/%lu",
        ok ? 1 : 0,
        (unsigned long)profile[0], (unsigned long)profile[1],
        (unsigned long)profile[2], (unsigned long)profile[3],
        (unsigned long)profile[4]
    );
}

static void screenshot_task(void *argument)
{
    (void)argument;
    // 直启 UI 的固件不会装 USB-Serial-JTAG 驱动（控制台走寄存器级 VFS），
    // 此时读寄存器会解引用空驱动对象，症状是"屏幕不停闪烁"的崩溃循环。
    // 这里显式安装驱动并把控制台切到驱动路径。
    usb_serial_jtag_driver_config_t config = {
        .tx_buffer_size = SCREENSHOT_TX_BUFFER,
        .rx_buffer_size = SCREENSHOT_RX_BUFFER,
    };
    while (usb_serial_jtag_driver_install(&config) != ESP_OK) {
        vTaskDelay(pdMS_TO_TICKS(SCREENSHOT_RETRY_MS));
    }
    usb_serial_jtag_vfs_use_driver();
    ESP_LOGI(TAG, "FAP_SCREENSHOT_V1 listener ready");

    // 匹配状态机在 MoonBit：state 是已连续命中的命令前缀字节数。
    int32_t matcher_state = passport_moonbit_screenshot_matcher_initial();
    uint8_t byte;
    for (;;) {
        if (!usb_serial_jtag_is_driver_installed()) {
            vTaskDelay(pdMS_TO_TICKS(SCREENSHOT_RETRY_MS));
            continue;
        }
        int received = usb_serial_jtag_read_bytes(&byte, 1, pdMS_TO_TICKS(50));
        if (received < 0) {
            // 错误路径退避，防止紧凑读循环饿死 idle 任务触发看门狗。
            vTaskDelay(pdMS_TO_TICKS(SCREENSHOT_RETRY_MS));
            continue;
        }
        if (received == 0) continue;
        matcher_state = passport_moonbit_screenshot_matcher_feed(
            matcher_state, (int32_t)byte);
        if (matcher_state == passport_moonbit_screenshot_command_length()) {
            matcher_state = passport_moonbit_screenshot_matcher_initial();
            send_reply();
        }
    }
}

void fap_screenshot_start(void)
{
    if (s_task_handle != NULL) return;
    if (xTaskCreate(
            screenshot_task,
            "fap_screenshot",
            SCREENSHOT_TASK_STACK,
            NULL,
            SCREENSHOT_TASK_PRIORITY,
            &s_task_handle) != pdPASS) {
        ESP_LOGW(TAG, "screenshot listener task unavailable");
        s_task_handle = NULL;
    }
}
