#include "fap_screenshot.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bsp_display.h"
#include "bsp_pins.h"
#include "driver/usb_serial_jtag.h"
#include "driver/usb_serial_jtag_vfs.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_interface.h"
#include "esp_lcd_panel_ops.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "moonbit_password.h"

#define TAG "fap_screenshot"

// LVGL 任务优先级为 4：串口辅助任务必须低于它，避免饿死渲染。
#define SCREENSHOT_TASK_PRIORITY 3
// 抽头在 LVGL 任务上下文里运行，栈用量必须小；8192 沿用整屏渲染期的余量。
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

// 条带尺寸与 BSP 对齐：components/bsp/src/bsp_display_lvgl.c 把 LVGL 部分
// 缓冲设为 BSP_LCD_W * 20 像素，所以一条带最多 20 行、9600 字节。
// 改那边必须同步改这里，超界的带会被判故障而不是越界写。
#define SCREENSHOT_BAND_ROWS 20
#define SCREENSHOT_BAND_MAX_BYTES (BSP_LCD_W * SCREENSHOT_BAND_ROWS * 2)
// 双槽轮转：抽头（生产者，LVGL 任务）与串口写出（消费者，本任务）解耦，
// 峰值常驻内存 2 * 9600 = 18.75KB，捕获结束即释放，不长期占着不给蓝牙。
#define SCREENSHOT_RING_SLOTS 2
// 槽位等待与首带等待的超时：宁可作废，也不让 LVGL 任务无限卡在抽头里。
#define SCREENSHOT_BAND_WAIT_MS 1500
#define SCREENSHOT_FIRST_BAND_WAIT_MS 1000

// 会话动作编号：与 moonbit/screenshot.mbt 的 action_* 一致，那边有
// "action codes match the C adapter constants" 单测钉住数值，改一边就会红。
// 故障词汇不在这里出现——C 通过 session_note_* 专用入口报告"发生了哪种事"。
#define ACTION_WAIT 0
#define ACTION_SEND_BAND 2
#define ACTION_DONE 3
#define ACTION_ABORT 4

// 无 PSRAM 的 ESP32-C3 上，内部 RAM 被切成 118,848 字节的常规堆区和另一个
// 116,496 字节的 retention 区：单次分配不能跨区，所以 153,600 字节的整屏
// 缓冲永远拿不到（实测挂起蓝牙后最大连续块只有 106,496）。蓝牙键盘自己
// 又要占约 115KB——"整屏一次成型"与"蓝牙在线"在算术上互斥，不是调参能解的。
//
// 所以不再攒齐整屏：LVGL 用 240x20 的部分缓冲刷新，每次 flush 本身就是一
// 条已经在内存里的条带。把面板的 draw_bitmap 换成抽头，逐条换回小端、拷进
// 双槽环、交给本任务直接写串口。峰值内存 18.75KB，蓝牙全程不挂起。线上
// 字节流与整屏缓冲时逐字节一致，主机端 tools/screenshot.py 不需要改动。
static TaskHandle_t s_task_handle;

// MoonBit 协议头字节经回调落入此缓冲（passport_moonbit_screenshot_header_build）。
static uint8_t s_header[SCREENSHOT_HEADER_MAX];
static size_t s_header_len;

// 诊断用的结果名同样由 MoonBit 生成（passport_moonbit_screenshot_result_name_build），
// C 侧只提供一块缓冲接字节，不再自己写一份 code→字符串的映射。
#define SCREENSHOT_NAME_MAX 16
static char s_result_name[SCREENSHOT_NAME_MAX];

typedef struct {
    size_t len;
    uint8_t bytes[SCREENSHOT_BAND_MAX_BYTES];
} screenshot_band_t;

static struct {
    screenshot_band_t *slots;
    SemaphoreHandle_t ready;
    SemaphoreHandle_t free;
    size_t write_index;
    size_t read_index;
    // armed 由抽头在 LVGL 任务里读、由本任务在 LVGL 锁内改写；锁的
    // 获取顺序保证置位/复位时不会有 flush 正在飞行（见 capture_disarm）。
    volatile bool armed;
    // rows 是带序进度，判定用得到 MoonBit 的会话记账，这里只留一份
    // 给诊断日志复读。
    volatile int32_t rows;
} s_capture;

static esp_lcd_panel_t *s_panel;
static esp_err_t (*s_draw_bitmap_next)(
    esp_lcd_panel_t *panel, int x_start, int y_start, int x_end, int y_end, const void *color_data);

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

void passport_screenshot_name_reset(void)
{
    s_result_name[0] = '\0';
}

int32_t passport_screenshot_name_push(int32_t ch)
{
    if (ch <= 0 || ch > 0x7F) return 0;
    const size_t length = strlen(s_result_name);
    if (length + 1 >= sizeof(s_result_name)) return 0;
    s_result_name[length] = (char)ch;
    s_result_name[length + 1] = '\0';
    return 1;
}

// 字节序策略由 MoonBit 给出（screenshot_band_swap_pairs）。抽头拿到的条带是
// esp_lvgl_port 为 SPI 屏做过大端原地交换之后的数据，而协议声明 RGB565LE，
// 所以要换回来。这个约定连同它的单测放在 MoonBit：换错一次就是一整张红蓝
// 互换的图，构建和真机都不会报错。这里只按标志执行。
static void band_copy(uint8_t *dst, const uint8_t *src, size_t bytes)
{
    if (passport_moonbit_screenshot_band_swap_pairs() == 1) {
        for (size_t index = 0; index + 1 < bytes; index += 2) {
            dst[index] = src[index + 1];
            dst[index + 1] = src[index];
        }
        return;
    }
    memcpy(dst, src, bytes);
}

// 故障归因全在 MoonBit；抽头这边只停计数并唤醒发送任务收尾。
static void capture_abort(void)
{
    s_capture.armed = false;
    (void)xSemaphoreGive(s_capture.ready);
}

// 运行在 LVGL 任务上下文里：判定与记账在 MoonBit，这里只负责等待与搬运。
static void capture_consume_band(
    int x_start, int y_start, int x_end, int y_end, const uint8_t *data)
{
    // 整帧已攒够或已出故障：之后来的带属于下一个刷新周期（LVGL 会从 y=0
    // 重画一遍），忽略并收手。若继续按带序判定，第二遍会被判"重叠"而作废，
    // 把已经完整的一帧整个丢掉。
    if (passport_moonbit_screenshot_session_accepting() != 1) {
        s_capture.armed = false;
        return;
    }
    const int32_t w = x_end - x_start;
    const int32_t h = y_end - y_start;
    const int64_t bytes_total = (int64_t)w * (int64_t)h * 2;
    // 槽位尺寸跟着 BSP 的 LVGL 缓冲定；超界必须先挡住，否则就是越界写，
    // 所以这道内存保护留在 C，语义判定才交给 MoonBit。
    if (bytes_total > SCREENSHOT_BAND_MAX_BYTES) {
        passport_moonbit_screenshot_session_note_band_fault();
        capture_abort();
        return;
    }
    // 带序、横向铺满、紧凑排布、不越面板下界——判定全在 MoonBit。
    const int32_t next = passport_moonbit_screenshot_band_feed(
        s_capture.rows,
        x_start,
        y_start,
        w,
        h,
        (int32_t)bytes_total,
        BSP_LCD_W,
        BSP_LCD_H);
    if (next < 0) {
        passport_moonbit_screenshot_session_note_band_fault();
        capture_abort();
        return;
    }
    if (xSemaphoreTake(
            s_capture.free, pdMS_TO_TICKS(SCREENSHOT_BAND_WAIT_MS)) != pdTRUE) {
        passport_moonbit_screenshot_session_note_stalled();
        capture_abort();
        return;
    }
    screenshot_band_t *slot = &s_capture.slots[s_capture.write_index];
    band_copy(slot->bytes, data, (size_t)bytes_total);
    slot->len = (size_t)bytes_total;
    s_capture.rows = next;
    s_capture.write_index = (s_capture.write_index + 1) % SCREENSHOT_RING_SLOTS;
    passport_moonbit_screenshot_session_produced((int32_t)bytes_total);
    (void)xSemaphoreGive(s_capture.ready);
}

static esp_err_t panel_draw_bitmap_tap(
    esp_lcd_panel_t *panel, int x_start, int y_start, int x_end, int y_end, const void *color_data)
{
    if (s_capture.armed) {
        capture_consume_band(
            x_start, y_start, x_end, y_end, (const uint8_t *)color_data);
    }
    return s_draw_bitmap_next
        ? s_draw_bitmap_next(panel, x_start, y_start, x_end, y_end, color_data)
        : ESP_OK;
}

// 抽头只在面板对象上换掉一个函数指针；常驻，非捕获期只是一次 volatile 读。
static bool panel_tap_install(void)
{
    if (s_panel != NULL) return true;
    esp_lcd_panel_handle_t panel = bsp_display_panel();
    if (panel == NULL || panel->draw_bitmap == NULL) {
        ESP_LOGW(TAG, "display panel unavailable; screenshot disabled");
        return false;
    }
    s_draw_bitmap_next = panel->draw_bitmap;
    panel->draw_bitmap = panel_draw_bitmap_tap;
    s_panel = panel;
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

static void capture_ring_release(void)
{
    if (s_capture.slots != NULL) {
        free(s_capture.slots);
        s_capture.slots = NULL;
    }
    if (s_capture.ready != NULL) {
        vSemaphoreDelete(s_capture.ready);
        s_capture.ready = NULL;
    }
    if (s_capture.free != NULL) {
        vSemaphoreDelete(s_capture.free);
        s_capture.free = NULL;
    }
}

// 环形缓冲只在捕获期临时申请（18.75KB），结束立刻归还：常驻会把蓝牙
// 配对期的动态内存一并挤掉，那就退化成"两个功能互斥"的老问题。
static bool capture_ring_acquire(void)
{
    if (s_capture.slots != NULL) return true;
    s_capture.ready = xSemaphoreCreateCounting(SCREENSHOT_RING_SLOTS, 0);
    s_capture.free = xSemaphoreCreateCounting(
        SCREENSHOT_RING_SLOTS, SCREENSHOT_RING_SLOTS);
    s_capture.slots = heap_caps_malloc(
        sizeof(screenshot_band_t) * SCREENSHOT_RING_SLOTS,
        MALLOC_CAP_8BIT | MALLOC_CAP_INTERNAL);
    if (s_capture.ready == NULL || s_capture.free == NULL ||
        s_capture.slots == NULL) {
        capture_ring_release();
        return false;
    }
    return true;
}

// 把环恢复成空：排空未消费的 ready 计数，再把 free 补满（计数信号量到上限
// 后 Give 会失败，正好当饱和保护）。上一次捕获若因主机拔线提前退出，槽位
// 与计数会残留，不重置就会让下一次抽到脏数据。
static void capture_ring_reset(void)
{
    while (xSemaphoreTake(s_capture.ready, 0) == pdTRUE) {
    }
    for (int index = 0; index < SCREENSHOT_RING_SLOTS; index++) {
        (void)xSemaphoreGive(s_capture.free);
    }
}

// 置位与强制整屏重绘必须在同一把 LVGL 锁里完成：抽头由 LVGL 任务在持锁
// 期间调用，锁内改写 armed 才能保证不会有半条带被计入。
static bool capture_arm(void)
{
    if (!bsp_lvgl_lock(SCREENSHOT_LVGL_LOCK_TIMEOUT_MS)) return false;
    capture_ring_reset();
    s_capture.rows = passport_moonbit_screenshot_band_initial();
    s_capture.write_index = 0;
    s_capture.read_index = 0;
    s_capture.armed = true;
    lv_obj_invalidate(lv_screen_active());
    bsp_lvgl_unlock();
    return true;
}

// 返回 true 表示已证明抽头不会再碰环形缓冲，调用方才可以释放它。
//
// 抽头可能正阻塞在等槽位上（主机拔线时最常见），所以先把 ready 排空并归还
// free 让它醒来；随后取一次 LVGL 锁——拿到锁即证明 LVGL 任务已不在 flush
// 之中，此刻释放缓冲不会与任何一次拷贝打架。取不到锁就保留环形缓冲（最多
// 18.75KB 常驻），下一次捕获继续复用，绝不冒释放后被写的风险。
static bool capture_disarm(void)
{
    s_capture.armed = false;
    while (xSemaphoreTake(s_capture.ready, 0) == pdTRUE) {
        (void)xSemaphoreGive(s_capture.free);
    }
    for (int attempt = 0; attempt < 4; attempt++) {
        if (bsp_lvgl_lock(SCREENSHOT_LVGL_LOCK_TIMEOUT_MS)) {
            bsp_lvgl_unlock();
            return true;
        }
    }
    return false;
}

// 按 MoonBit 给出的动作把环里的条带依次写出去。C 这边不再自己判断"写完了
// 没有"——那是会话记账的职责，双槽下抽头会跑在发送任务前面，用错计数器就
// 会静默丢掉尾带，所以那条规则连同它的单测都在 moonbit/screenshot.mbt。
static void stream_bands(void)
{
    for (;;) {
        const int32_t action = passport_moonbit_screenshot_session_action();
        if (action == ACTION_DONE || action == ACTION_ABORT) {
            return;
        }
        if (action == ACTION_WAIT) {
            if (xSemaphoreTake(
                    s_capture.ready,
                    pdMS_TO_TICKS(SCREENSHOT_BAND_WAIT_MS)) != pdTRUE) {
                passport_moonbit_screenshot_session_note_timed_out();
            }
            continue;
        }
        if (action != ACTION_SEND_BAND) {
            // 未知动作说明两边编号不一致（MoonBit 有钉桩单测），作废。
            passport_moonbit_screenshot_session_note_header();
            return;
        }
        screenshot_band_t *slot = &s_capture.slots[s_capture.read_index];
        // 长度必须在归还槽位之前取走：Give 之后抽头随时会覆写这个槽。
        const size_t length = slot->len;
        if (!write_chunked(slot->bytes, length)) {
            passport_moonbit_screenshot_session_note_transport();
            return;
        }
        s_capture.read_index = (s_capture.read_index + 1) % SCREENSHOT_RING_SLOTS;
        (void)xSemaphoreGive(s_capture.free);
        passport_moonbit_screenshot_session_band_sent((int32_t)length);
    }
}

static void send_reply(void)
{
    // 静音窗口覆盖整个捕获期：日志与应答共用同一路 USB-CDC，混入一个字节
    // 整幅图就错位。抽头本身不打日志，结果统一在收尾那一行报出。
    esp_log_level_set("*", ESP_LOG_NONE);

    const int32_t payload =
        passport_moonbit_screenshot_session_begin(BSP_LCD_W, BSP_LCD_H);
    bool ring_quiescent = true;

    if (!panel_tap_install() || !capture_ring_acquire()) {
        passport_moonbit_screenshot_session_note_no_memory();
    } else if (!capture_arm()) {
        passport_moonbit_screenshot_session_note_no_lock();
    } else {
        // 先等到第一条带再发协议头：整场失败时主机看到的是"设备没应答"，
        // 而不是收到头之后干等一堆永远不来的像素。这条策略也在 MoonBit。
        if (xSemaphoreTake(
                s_capture.ready,
                pdMS_TO_TICKS(SCREENSHOT_FIRST_BAND_WAIT_MS)) != pdTRUE) {
            passport_moonbit_screenshot_session_note_timed_out();
        } else if (passport_moonbit_screenshot_session_header_allowed() == 1) {
            const int32_t header_len = passport_moonbit_screenshot_header_build(
                BSP_LCD_W, BSP_LCD_H, payload);
            if (header_len <= 0 || (size_t)header_len != s_header_len) {
                passport_moonbit_screenshot_session_note_header();
            } else if (!write_chunked(s_header, s_header_len)) {
                passport_moonbit_screenshot_session_note_transport();
            } else {
                stream_bands();
            }
            (void)usb_serial_jtag_wait_tx_done(
                pdMS_TO_TICKS(SCREENSHOT_WRITE_TIMEOUT_MS));
        }
        ring_quiescent = capture_disarm();
    }

    if (ring_quiescent) {
        capture_ring_release();
    }
    esp_log_level_set("*", CONFIG_LOG_DEFAULT_LEVEL);
    /* 结果码与可读名字都由 MoonBit 给出；主机端重同步会跳过这一行。 */
    (void)passport_moonbit_screenshot_result_name_build(
        passport_moonbit_screenshot_session_result());
    ESP_LOGI(
        TAG,
        "capture %s rows=%ld/%d payload=%ld ring=%s largest=%lu free=%lu",
        s_result_name,
        (long)s_capture.rows,
        BSP_LCD_H,
        (long)payload,
        ring_quiescent ? "freed" : "retained",
        (unsigned long)heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL),
        (unsigned long)heap_caps_get_free_size(MALLOC_CAP_INTERNAL)
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
