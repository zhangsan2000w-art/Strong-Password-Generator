#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void moonbit_init(void);
uint64_t passport_moonbit_diagnostic_observation_initial(void);
uint64_t passport_moonbit_diagnostic_policy_state(uint64_t state);
uint64_t passport_moonbit_diagnostic_observe_character(uint64_t policy_state, uint64_t observation, int32_t character);
uint64_t passport_moonbit_diagnostic_run_initial(int32_t target);
uint64_t passport_moonbit_diagnostic_record_sample(uint64_t run, uint64_t policy_state, uint64_t observation, int32_t generation_result);
uint64_t passport_moonbit_diagnostic_cancel_run(uint64_t run);
int32_t passport_moonbit_diagnostic_run_target(uint64_t run);
int32_t passport_moonbit_diagnostic_run_completed(uint64_t run);
int32_t passport_moonbit_diagnostic_run_passed(uint64_t run);
int32_t passport_moonbit_diagnostic_run_failure(uint64_t run);
int32_t passport_moonbit_diagnostic_run_status(uint64_t run);
int32_t passport_moonbit_policy_profile_normalize(int32_t profile);
int32_t passport_moonbit_policy_profile_default_length(int32_t profile);
int32_t passport_moonbit_policy_profile_min_length(int32_t profile);
int32_t passport_moonbit_policy_profile_symbols(int32_t profile);
int32_t passport_moonbit_policy_profile_exclude_ambiguous(int32_t profile);
int32_t passport_moonbit_policy_profile_safe_symbols_only(int32_t profile);
uint64_t passport_moonbit_initial_state(void);
uint64_t passport_moonbit_with_policy_profile(uint64_t state, int32_t profile);
uint64_t passport_moonbit_with_policy_settings(uint64_t state, int32_t profile, int32_t exclude_ambiguous);
uint64_t passport_moonbit_handle_input(uint64_t state, int32_t input);
int32_t passport_moonbit_state_get(uint64_t state, int32_t requested);
int32_t passport_moonbit_state_action(uint64_t state);
int32_t passport_moonbit_ble_keyboard_report(int32_t character);
int32_t passport_moonbit_ble_keyboard_status(int32_t status);
int32_t passport_moonbit_ble_keyboard_send_allowed(uint64_t state, int32_t status);
int32_t passport_moonbit_ble_keyboard_input_allowed(int32_t status);
int32_t passport_moonbit_ble_keyboard_should_advertise(int32_t status, int32_t connected, int32_t advertising);
int32_t passport_moonbit_ble_keyboard_retry_ms(void);
int32_t passport_moonbit_ble_keyboard_link_event(int32_t state, int32_t event);
int32_t passport_moonbit_ble_keyboard_link_ready(int32_t state);
int32_t passport_moonbit_ble_keyboard_pairing_timeout_ms(void);
int32_t passport_moonbit_ble_keyboard_pairing_stalled(int32_t state, int32_t elapsed_ms);
int32_t passport_moonbit_ble_keyboard_link_status(int32_t state);
int32_t passport_moonbit_ble_keyboard_action(uint64_t state, int32_t status);
int32_t passport_moonbit_generate(uint64_t state);
int32_t passport_moonbit_entropy_x10(uint64_t state);
int32_t passport_moonbit_strength(uint64_t state);
int32_t passport_moonbit_security_warning(uint64_t state);
int32_t passport_moonbit_configuration_valid(uint64_t state);
int32_t passport_moonbit_configuration_changed(uint64_t before, uint64_t after);
uint64_t passport_moonbit_record_generation(uint64_t state, int32_t result);
int32_t passport_moonbit_password_display_begin(uint64_t state);
int32_t passport_moonbit_password_display_is_visible(int32_t mode);
int32_t passport_moonbit_password_display_update(uint64_t state, int32_t current, uint64_t elapsed_ms);
uint64_t passport_moonbit_password_display_timeout_ms(void);
int32_t passport_moonbit_password_display_mask_width(void);
int32_t passport_moonbit_password_display_mask_character(void);
int32_t passport_moonbit_map_button_event(uint64_t state, int32_t button, int32_t event);
int32_t passport_moonbit_mode_max_focus(int32_t mode);
int32_t passport_moonbit_view_parameter_kind(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_value(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_x(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_y(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_width(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_height(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_selected(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_parameter_editing(uint64_t state, int32_t slot);
int32_t passport_moonbit_view_mode_selected(uint64_t state, int32_t mode);
int32_t passport_moonbit_view_mode_focused(uint64_t state, int32_t mode);
int32_t passport_moonbit_view_generate_focused(uint64_t state);
int32_t passport_moonbit_view_send_focused(uint64_t state);
int32_t passport_moonbit_view_theme(uint64_t state);
uint64_t passport_moonbit_with_theme(uint64_t state, int32_t theme);
uint64_t passport_moonbit_settings_initial(int32_t theme, int32_t sound_enabled, int32_t policy_profile, int32_t exclude_ambiguous);
uint64_t passport_moonbit_settings_handle_input(uint64_t state, int32_t input);
int32_t passport_moonbit_settings_map_button_event(int32_t button, int32_t event);
int32_t passport_moonbit_settings_selected(uint64_t state);
int32_t passport_moonbit_settings_action(uint64_t state);
int32_t passport_moonbit_settings_theme(uint64_t state);
int32_t passport_moonbit_settings_sound_enabled(uint64_t state);
int32_t passport_moonbit_settings_policy_profile(uint64_t state);
int32_t passport_moonbit_settings_exclude_ambiguous(uint64_t state);
int32_t passport_moonbit_battery_resolve(int32_t percent, int32_t millivolts);
int32_t passport_moonbit_battery_percent(int32_t reading);
int32_t passport_moonbit_battery_available(int32_t reading);
int32_t passport_moonbit_battery_estimated(int32_t reading);
int32_t passport_moonbit_battery_low(int32_t reading);
int32_t passport_moonbit_battery_refresh_interval_ms(void);
int32_t passport_moonbit_sound_sample_rate(void);
int32_t passport_moonbit_sound_volume(void);
int32_t passport_moonbit_sound_note_count(void);
int32_t passport_moonbit_sound_note_samples(int32_t note);
int32_t passport_moonbit_sound_sample(int32_t note, int32_t sample_index);
/* Status-line wording for the result area (moonbit/status_text.mbt).
 * Builds UTF-8 bytes into a C-side buffer via passport_status_text_*;
 * returns the byte count, which C must match against what it actually got. */
int32_t passport_moonbit_status_text_build(int32_t profile, int32_t warning);

/* Persisted-settings sanitisation: one entry point shared by the NVS load
 * path and every setter (moonbit/settings.mbt). */
int32_t passport_moonbit_settings_sanitize_theme(int32_t raw);
int32_t passport_moonbit_settings_sanitize_policy_profile(int32_t raw);
int32_t passport_moonbit_settings_sanitize_flag(int32_t raw);

/* FAP_SCREENSHOT_V1 serial screenshot protocol core (moonbit/screenshot.mbt). */
int32_t passport_moonbit_screenshot_command_length(void);
int32_t passport_moonbit_screenshot_matcher_initial(void);
int32_t passport_moonbit_screenshot_matcher_feed(int32_t state, int32_t byte);
int32_t passport_moonbit_screenshot_header_build(int32_t width, int32_t height, int32_t payload);
/* Band-stream capture accounting: returns the new covered-row count (>=0) or a
 * negated error code (<0). See moonbit/screenshot.mbt for the invariants. */
int32_t passport_moonbit_screenshot_band_initial(void);
int32_t passport_moonbit_screenshot_band_feed(
    int32_t rows,
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    int32_t byte_len,
    int32_t expected_width,
    int32_t expected_height);
int32_t passport_moonbit_screenshot_band_complete(int32_t rows, int32_t expected_height);
/* Panel-tap byte order policy: 1 = swap RGB565 pairs on the way out. */
int32_t passport_moonbit_screenshot_band_swap_pairs(void);
/* Capture session accounting. C reports events and asks what to do next;
 * "when is a frame complete" lives here so it can be host-tested. */
int32_t passport_moonbit_screenshot_session_begin(int32_t width, int32_t height);
void passport_moonbit_screenshot_session_produced(int32_t bytes);
void passport_moonbit_screenshot_session_note_fault(int32_t code);
void passport_moonbit_screenshot_session_note_band_fault(void);
void passport_moonbit_screenshot_session_note_stalled(void);
void passport_moonbit_screenshot_session_note_timed_out(void);
void passport_moonbit_screenshot_session_note_transport(void);
void passport_moonbit_screenshot_session_note_no_memory(void);
void passport_moonbit_screenshot_session_note_header(void);
void passport_moonbit_screenshot_session_note_no_lock(void);
int32_t passport_moonbit_screenshot_session_header_allowed(void);
/* 1 while the tap should still accept strips; 0 once the frame is whole. */
int32_t passport_moonbit_screenshot_session_accepting(void);
int32_t passport_moonbit_screenshot_session_action(void);
int32_t passport_moonbit_screenshot_session_band_sent(int32_t bytes);
int32_t passport_moonbit_screenshot_session_result(void);
/* Result label for the diagnostic log line, pushed into a C-side buffer. */
int32_t passport_moonbit_screenshot_result_name_build(int32_t result);

#ifdef __cplusplus
}
#endif
