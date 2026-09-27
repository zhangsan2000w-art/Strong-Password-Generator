#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

typedef enum {
    PASSWORD_BLE_STARTING = 0,
    PASSWORD_BLE_ADVERTISING = 1,
    PASSWORD_BLE_PAIRING = 2,
    PASSWORD_BLE_CONNECTED = 3,
    PASSWORD_BLE_SENDING = 4,
    PASSWORD_BLE_SENT = 5,
    PASSWORD_BLE_ERROR = 6,
    PASSWORD_BLE_RELEASED = 7,
} password_ble_status_t;

esp_err_t password_ble_keyboard_init(void);
esp_err_t password_ble_keyboard_send(const char *password);
esp_err_t password_ble_keyboard_resume(void);
password_ble_status_t password_ble_keyboard_status(void);
void password_ble_keyboard_poll(void);
void password_ble_keyboard_reset_feedback(void);
/* Suspend the whole BLE stack (host + controller) to free its internal RAM
 * for a full-screen snapshot, then resume advertising afterwards. Suspend
 * refuses while pairing/typing is in progress; the NVS bond survives, so a
 * suspended-while-connected peer can simply reconnect. */
bool password_ble_keyboard_stack_suspend(void);
void password_ble_keyboard_stack_resume(void);
/* Copy the free-internal-heap snapshot taken at each suspend stage
 * (before / after HID deinit / after NimBLE deinit / after controller
 * deinit / final) for diagnostics. */
void password_ble_keyboard_suspend_profile(uint32_t out[5]);
