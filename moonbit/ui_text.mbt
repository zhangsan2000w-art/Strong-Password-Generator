///|
// 界面文案的唯一来源：参数槽位标签、电量读数、BLE 状态行与发送按钮、结果区
// 占位/失败/完成句、熵读数、生成/重新生成按钮，以及设置页的选项名、取值、
// 提示语和自检文案。
//
// 这些原本是 main/password_app.c 与 main/settings_screen.c 里的
// lv_label_set_text_fmt 字面量和 switch 分支：措辞、ON/OFF、分隔符表、状态到
// 句子的映射都散在 C 里，没有地方断言用户最终读到什么。现在它们在这里被单测
// 钉住，C 只把 LVGL 标签指向共享缓冲（main/ui_text.c）。

///|
// UTF-8 编码。MoonBit 的 Char#to_int() 给的是 Unicode 码点，而 LVGL 标签要的是
// UTF-8 字节；标准库这一版没有现成编码器，手写部分用已知向量钉住
// （ui_text_test.mbt）。
pub fn utf8_byte_count(codepoint : Int) -> Int {
  if codepoint < 0x80 {
    1
  } else if codepoint < 0x800 {
    2
  } else if codepoint < 0x1_0000 {
    3
  } else {
    4
  }
}

///|
// 把码点编成 UTF-8 逐字节交给 put，返回写出的字节数。
pub fn emit_codepoint_utf8(codepoint : Int, put : (Int) -> Unit) -> Int {
  let bytes = utf8_byte_count(codepoint)
  if bytes == 1 {
    put(codepoint)
  } else if bytes == 2 {
    put(0xC0 + (codepoint >> 6))
    put(0x80 + (codepoint & 0x3F))
  } else if bytes == 3 {
    put(0xE0 + (codepoint >> 12))
    put(0x80 + ((codepoint >> 6) & 0x3F))
    put(0x80 + (codepoint & 0x3F))
  } else {
    put(0xF0 + (codepoint >> 18))
    put(0x80 + ((codepoint >> 12) & 0x3F))
    put(0x80 + ((codepoint >> 6) & 0x3F))
    put(0x80 + (codepoint & 0x3F))
  }
  bytes
}

///|
pub fn emit_text_utf8(text : String, put : (Int) -> Unit) -> Int {
  let mut count = 0
  for ch in text {
    count = count + emit_codepoint_utf8(ch.to_int(), put)
  }
  count
}

///|
// 文案种类，与 main/ui_text.h 的 UI_TEXT_* 枚举一一对应。
pub let ui_text_param_label : Int = 0

///|
pub let ui_text_battery : Int = 1

///|
pub let ui_text_battery_unavailable : Int = 2

///|
pub let ui_text_ble_status : Int = 3

///|
pub let ui_text_send_button : Int = 4

///|
pub let ui_text_result_failure : Int = 5

///|
pub let ui_text_result_done : Int = 6

///|
pub let ui_text_result_placeholder : Int = 7

///|
pub let ui_text_entropy : Int = 8

///|
pub let ui_text_generate_button : Int = 9

///|
pub let ui_text_settings_name : Int = 10

///|
pub let ui_text_settings_value : Int = 11

///|
pub let ui_text_settings_hint : Int = 12

///|
pub let ui_text_diagnostic_status : Int = 13

///|
pub let ui_text_diagnostic_progress : Int = 14

///|
pub let ui_text_count : Int = 15

///|
// 分隔符按下标取，越界回落第一个（与原 C 的 separator_text[value] 不同：
/// 原实现越界会读越界内存，这里钉成确定的回落）。
let ui_text_parameter_separators : Array[String] = ["-", ".", "_"]

///|
fn ui_text_on_off(value : Int) -> String {
  if value != 0 {
    "ON"
  } else {
    "OFF"
  }
}

///|
// 参数槽位标签。kind 取自 view_model.mbt 的 parameter_* 常量。
fn ui_text_parameter_label(kind : Int, value : Int) -> String {
  if kind == parameter_random_length {
    "长度 \{value}"
  } else if kind == parameter_lowercase {
    "小写 \{ui_text_on_off(value)}"
  } else if kind == parameter_uppercase {
    "大写 \{ui_text_on_off(value)}"
  } else if kind == parameter_digits {
    "数字 \{ui_text_on_off(value)}"
  } else if kind == parameter_symbols {
    "符号 \{ui_text_on_off(value)}"
  } else if kind == parameter_word_count {
    "单词数 \{value}"
  } else if kind == parameter_capitalize {
    "首字母 \{ui_text_on_off(value)}"
  } else if kind == parameter_complete_word {
    "完整单词 \{ui_text_on_off(value)}"
  } else if kind == parameter_separator {
    let separator = if value >= 0 &&
      value < ui_text_parameter_separators.length() {
      ui_text_parameter_separators[value]
    } else {
      ui_text_parameter_separators[0]
    }
    "分隔符 \{separator}"
  } else if kind == parameter_pin_length {
    "PIN 位数 \{value}"
  } else {
    ""
  }
}

///|
// BLE 状态行。status 取自 ble_keyboard.mbt 的 ble_keyboard_* 常量；
// 其余（含 error）统一读作不可用。
fn ui_text_ble_status_label(status : Int) -> String {
  if status == ble_keyboard_starting {
    "BLE 启动中"
  } else if status == ble_keyboard_advertising {
    "BLE: 配对 FoloPassKey"
  } else if status == ble_keyboard_pairing {
    "BLE 连接中 无需配对码"
  } else if status == ble_keyboard_connected {
    "BLE 已连接 可发送"
  } else if status == ble_keyboard_sending {
    "正在输入密码..."
  } else if status == ble_keyboard_sent {
    "密码已发送"
  } else if status == ble_keyboard_released {
    "已发送，系统键盘已恢复"
  } else {
    "BLE 不可用"
  }
}

///|
fn ui_text_theme_label(theme : Int) -> String {
  if theme == theme_sky {
    "Sky"
  } else {
    "Cyber"
  }
}

///|
fn ui_text_policy_label(profile : Int) -> String {
  if profile == policy_profile_compatible {
    "Compat"
  } else if profile == policy_profile_strict {
    "Strict"
  } else {
    "Standard"
  }
}

///|
fn ui_settings_name_text(index : Int) -> String {
  if index == settings_option_theme {
    "Theme"
  } else if index == settings_option_sound {
    "Sound"
  } else if index == settings_option_policy_profile {
    "Policy"
  } else if index == settings_option_exclude_ambiguous {
    "Clear chars"
  } else if index == settings_option_self_check {
    "Self-check"
  } else {
    ""
  }
}

///|
// 设置项右侧取值。自检项固定显示 RUN，其余按当前取值渲染。
fn ui_settings_value_text(index : Int, value : Int) -> String {
  if index == settings_option_theme {
    ui_text_theme_label(value)
  } else if index == settings_option_policy_profile {
    ui_text_policy_label(value)
  } else if index == settings_option_self_check {
    "RUN"
  } else if index == settings_option_sound ||
    index == settings_option_exclude_ambiguous {
    ui_text_on_off(value)
  } else {
    ""
  }
}

///|
// 底部提示语：0 是设置页，1 是自检页。
fn ui_settings_hint_text(kind : Int) -> String {
  if kind == 0 {
    "OK: change   LONG: back"
  } else {
    "LONG: cancel / back"
  }
}

///|
fn ui_text_diagnostic_status_label(status : Int) -> String {
  if status == diagnostic_status_running {
    "Checking..."
  } else if status == diagnostic_status_passed {
    "PASS"
  } else if status == diagnostic_status_cancelled {
    "Canceled"
  } else if status == diagnostic_status_failed {
    "FAIL"
  } else {
    ""
  }
}

///|
// 自检详情句。状态之外还要 completed/target/passed/failure 四个数，
// 因此单独一个入口，不塞进 (a, b) 两参数里。
pub fn ui_diagnostic_detail(
  status : Int,
  completed : Int,
  target : Int,
  passed : Int,
  failure : Int,
) -> String {
  if status == diagnostic_status_running {
    "No samples are stored"
  } else if status == diagnostic_status_passed {
    "\{passed} / \{target} passed"
  } else if status == diagnostic_status_cancelled {
    "Stopped after \{completed} samples"
  } else if status == diagnostic_status_failed {
    "\{passed} passed  Error \{failure}"
  } else {
    ""
  }
}

///|
// 通用文案入口：kind 取 ui_text_* 常量，a/b 是该类文案的参数。
pub fn ui_text_with(kind : Int, a : Int, b : Int) -> String {
  if kind == ui_text_param_label {
    ui_text_parameter_label(a, b)
  } else if kind == ui_text_battery {
    if b != 0 {
      "~\{a}%"
    } else {
      "\{a}%"
    }
  } else if kind == ui_text_battery_unavailable {
    "--%"
  } else if kind == ui_text_ble_status {
    ui_text_ble_status_label(a)
  } else if kind == ui_text_send_button {
    if a != 0 {
      "重新连接"
    } else {
      "发送"
    }
  } else if kind == ui_text_result_failure {
    "生成失败 请重试"
  } else if kind == ui_text_result_done {
    "已生成"
  } else if kind == ui_text_result_placeholder {
    "OK -> Generate"
  } else if kind == ui_text_entropy {
    "H \{a / 10}.\{a % 10} bit"
  } else if kind == ui_text_generate_button {
    if a != 0 {
      "重新生成"
    } else {
      "生成"
    }
  } else if kind == ui_text_settings_name {
    ui_settings_name_text(a)
  } else if kind == ui_text_settings_value {
    ui_settings_value_text(a, b)
  } else if kind == ui_text_settings_hint {
    ui_settings_hint_text(a)
  } else if kind == ui_text_diagnostic_status {
    ui_text_diagnostic_status_label(a)
  } else if kind == ui_text_diagnostic_progress {
    "\{a} / \{b} samples"
  } else {
    ""
  }
}

///|
extern "C" fn platform_ui_text_reset() -> Unit = "passport_ui_text_reset"

///|
extern "C" fn platform_ui_text_push(ch : Int) -> Bool = "passport_ui_text_push"

///|
// 面向固件：UTF-8 字节经 platform 回调落到 C 侧共享缓冲，返回应写入的字节数。
// C 侧必须核对自己实际收到的长度一致；不一致说明文案超出缓冲，
// 此时保留上一帧而不是显示半截句子（main/ui_text.c 的 ui_text_collected）。
#export_name("passport_moonbit_ui_text_build")
pub fn ui_text_build(kind : Int, a : Int, b : Int) -> Int {
  platform_ui_text_reset()
  emit_text_utf8(ui_text_with(kind, a, b), fn(ch) {
    let _ = platform_ui_text_push(ch)
  })
}

///|
#export_name("passport_moonbit_diagnostic_detail_build")
pub fn diagnostic_detail_build(
  status : Int,
  completed : Int,
  target : Int,
  passed : Int,
  failure : Int,
) -> Int {
  platform_ui_text_reset()
  emit_text_utf8(
    ui_diagnostic_detail(status, completed, target, passed, failure),
    fn(ch) {
      let _ = platform_ui_text_push(ch)
    },
  )
}
