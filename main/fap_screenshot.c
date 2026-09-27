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

// 满屏 RGB565 缓冲在首次截屏时才从内部堆分配、成功后常驻复用：
// 启动阶段必须把内部 RAM 完整留给 NimBLE（HCI/控制器要大块连续内存，
// 静态预留 150KB 会直接让 nimble host init failed，蓝牙整体不可用）。
static uint8_t *s_snapshot_pixels;
static lv_draw_buf_t s_snapshot_buf;
static bool s_snapshot_buf_ready;
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

static void ensure_snapshot_buffer(void)
{
    if (s_snapshot_pixels != NULL) return;
    // 首次截屏才分配；成功后常驻（不释放，避免反复分配产生碎片）。
    s_snapshot_pixels = heap_caps_malloc(
        BSP_LCD_W * BSP_LCD_H * 2, MALLOC_CAP_8BIT | MALLOC_CAP_INTERNAL);
    if (s_snapshot_pixels == NULL) {
        ESP_LOGW(TAG, "snapshot buffer unavailable; capture skipped");
        return;
    }
    // stride 显式取 width*2，保证紧凑排布（本板 LV_DRAW_BUF_STRIDE_ALIGN=1）。
    (void)lv_draw_buf_init(
        &s_snapshot_buf,
        BSP_LCD_W,
        BSP_LCD_H,
        LV_COLOR_FORMAT_RGB565,
        BSP_LCD_W * 2,
        s_snapshot_pixels,
        BSP_LCD_W * BSP_LCD_H * 2
    );
    s_snapshot_buf_ready = true;
}

static bool render_snapshot(void)
{
    ensure_snapshot_buffer();
    if (!s_snapshot_buf_ready) return false;
    // LVGL 非线程安全：只在渲染瞬间持锁，传输期间 UI 照常刷新。
    if (!bsp_lvgl_lock(SCREENSHOT_LVGL_LOCK_TIMEOUT_MS)) {
        ESP_LOGW(TAG, "LVGL lock timeout; screenshot skipped");
        return false;
    }
    lv_result_t result = lv_snapshot_take_to_draw_buf(
        lv_screen_active(), LV_COLOR_FORMAT_RGB565, &s_snapshot_buf);
    bsp_lvgl_unlock();
    if (result != LV_RESULT_OK) {
        ESP_LOGW(TAG, "lv_snapshot_take_to_draw_buf failed");
        return false;
    }
    // 几何校验逻辑在 MoonBit（moonbit/screenshot.mbt）：只放行
    // 与 BSP 面板一致的紧凑满屏 RGB565；不符宁可不发（失败要静默）。
    if (passport_moonbit_screenshot_geometry_ok(
            (int32_t)s_snapshot_buf.header.w,
            (int32_t)s_snapshot_buf.header.h,
            (int32_t)s_snapshot_buf.header.stride,
            (int32_t)s_snapshot_buf.data_size,
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
    if (!render_snapshot()) return;

    const int32_t payload = BSP_LCD_W * BSP_LCD_H * 2;
    const int32_t header_len = passport_moonbit_screenshot_header_build(
        BSP_LCD_W, BSP_LCD_H, payload);
    if (header_len <= 0 || (size_t)header_len != s_header_len) {
        ESP_LOGW(TAG, "protocol header build failed");
        return;
    }

    // 二进制窗口内必须静音：日志与应答共用同一路 USB-CDC，
    // 混入一个日志字节整幅图就错位。恢复与后续日志严格放在窗口之外。
    esp_log_level_set("*", ESP_LOG_NONE);
    const bool ok = write_chunked(s_header, s_header_len) &&
                    write_chunked(s_snapshot_pixels, (size_t)payload);
    (void)usb_serial_jtag_wait_tx_done(pdMS_TO_TICKS(SCREENSHOT_WRITE_TIMEOUT_MS));
    esp_log_level_set("*", CONFIG_LOG_DEFAULT_LEVEL);

    if (!ok) {
        ESP_LOGW(TAG, "host disconnected during transfer; reply abandoned");
    }
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
