///|
// UTF-8 编码器单独用已知向量钉住，避免"用被测函数验证被测函数"。
test "utf8 encoder matches known byte vectors" {
  let buffer : Array[Int] = []
  let count = emit_text_utf8("策略", fn(ch) { buffer.push(ch) })
  @test.assert_eq(count, 6)
  @test.assert_eq(buffer, [0xE7, 0xAD, 0x96, 0xE7, 0x95, 0xA5])
  let ascii : Array[Int] = []
  @test.assert_eq(emit_text_utf8("ON", fn(ch) { ascii.push(ch) }), 2)
  @test.assert_eq(ascii, [0x4F, 0x4E])
  let emoji : Array[Int] = []
  @test.assert_eq(emit_text_utf8("😀", fn(ch) { emoji.push(ch) }), 4)
  @test.assert_eq(emoji, [0xF0, 0x9F, 0x98, 0x80])
  @test.assert_eq(utf8_byte_count(0x41), 1)
  @test.assert_eq(utf8_byte_count(0x7F), 1)
  @test.assert_eq(utf8_byte_count(0x80), 2)
  @test.assert_eq(utf8_byte_count(0x7FF), 2)
  @test.assert_eq(utf8_byte_count(0x800), 3)
  @test.assert_eq(utf8_byte_count(0xFFFF), 3)
  @test.assert_eq(utf8_byte_count(0x1_0000), 4)
}

///|
test "parameter labels name every slot and reflect booleans" {
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_random_length, 10),
    "长度 10",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_lowercase, 1),
    "小写 ON",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_uppercase, 0),
    "大写 OFF",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_digits, 1),
    "数字 ON",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_symbols, 0),
    "符号 OFF",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_word_count, 4),
    "单词数 4",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_capitalize, 1),
    "首字母 ON",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_complete_word, 1),
    "完整单词 ON",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_separator, 0),
    "分隔符 -",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_separator, 1),
    "分隔符 .",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_separator, 2),
    "分隔符 _",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_pin_length, 6),
    "PIN 位数 6",
  )
}

///|
// 隐藏槽位与未知种类都不出句子；越界的分隔符下标回落 "-" 而不是读越界。
test "hidden and unknown parameter kinds render nothing" {
  @test.assert_eq(ui_text_with(ui_text_param_label, parameter_hidden, 0), "")
  @test.assert_eq(ui_text_with(ui_text_param_label, 99, 0), "")
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_separator, 9),
    "分隔符 -",
  )
  @test.assert_eq(
    ui_text_with(ui_text_param_label, parameter_separator, -1),
    "分隔符 -",
  )
}

///|
// BLE 状态到句子的映射逐条钉住：写错一个状态用户就会读到错的动作提示。
test "every BLE status has its own sentence" {
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_starting, 0),
    "BLE 启动中",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_advertising, 0),
    "BLE: 配对 FoloPassKey",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_pairing, 0),
    "BLE 连接中 无需配对码",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_connected, 0),
    "BLE 已连接 可发送",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_sending, 0),
    "正在输入密码...",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_sent, 0),
    "密码已发送",
  )
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_released, 0),
    "已发送，系统键盘已恢复",
  )
  // error 与任何未知状态都读作不可用。
  @test.assert_eq(
    ui_text_with(ui_text_ble_status, ble_keyboard_error, 0),
    "BLE 不可用",
  )
  @test.assert_eq(ui_text_with(ui_text_ble_status, 42, 0), "BLE 不可用")
}

///|
test "battery, entropy and button labels" {
  @test.assert_eq(ui_text_with(ui_text_battery, 77, 0), "77%")
  @test.assert_eq(ui_text_with(ui_text_battery, 77, 1), "~77%")
  @test.assert_eq(ui_text_with(ui_text_battery_unavailable, 0, 0), "--%")
  @test.assert_eq(ui_text_with(ui_text_entropy, 52, 0), "H 5.2 bit")
  @test.assert_eq(ui_text_with(ui_text_entropy, 7, 0), "H 0.7 bit")
  @test.assert_eq(ui_text_with(ui_text_entropy, 120, 0), "H 12.0 bit")
  @test.assert_eq(ui_text_with(ui_text_generate_button, 0, 0), "生成")
  @test.assert_eq(ui_text_with(ui_text_generate_button, 1, 0), "重新生成")
  @test.assert_eq(ui_text_with(ui_text_send_button, 0, 0), "发送")
  @test.assert_eq(ui_text_with(ui_text_send_button, 1, 0), "重新连接")
}

///|
test "result area wording is fixed" {
  @test.assert_eq(
    ui_text_with(ui_text_result_failure, 0, 0),
    "生成失败 请重试",
  )
  @test.assert_eq(ui_text_with(ui_text_result_done, 0, 0), "已生成")
  @test.assert_eq(
    ui_text_with(ui_text_result_placeholder, 0, 0),
    "OK -> Generate",
  )
}

///|
test "settings names, values and hints" {
  @test.assert_eq(ui_text_with(ui_text_settings_name, 0, 0), "Theme")
  @test.assert_eq(ui_text_with(ui_text_settings_name, 1, 0), "Sound")
  @test.assert_eq(ui_text_with(ui_text_settings_name, 2, 0), "Policy")
  @test.assert_eq(ui_text_with(ui_text_settings_name, 3, 0), "Clear chars")
  @test.assert_eq(ui_text_with(ui_text_settings_name, 4, 0), "Self-check")
  @test.assert_eq(ui_text_with(ui_text_settings_name, 5, 0), "")

  @test.assert_eq(ui_text_with(ui_text_settings_value, 0, theme_cyber), "Cyber")
  @test.assert_eq(ui_text_with(ui_text_settings_value, 0, theme_sky), "Sky")
  @test.assert_eq(ui_text_with(ui_text_settings_value, 1, 1), "ON")
  @test.assert_eq(ui_text_with(ui_text_settings_value, 1, 0), "OFF")
  @test.assert_eq(
    ui_text_with(ui_text_settings_value, 2, policy_profile_compatible),
    "Compat",
  )
  @test.assert_eq(
    ui_text_with(ui_text_settings_value, 2, policy_profile_standard),
    "Standard",
  )
  @test.assert_eq(
    ui_text_with(ui_text_settings_value, 2, policy_profile_strict),
    "Strict",
  )
  @test.assert_eq(ui_text_with(ui_text_settings_value, 3, 1), "ON")
  @test.assert_eq(ui_text_with(ui_text_settings_value, 4, 0), "RUN")

  @test.assert_eq(
    ui_text_with(ui_text_settings_hint, 0, 0),
    "OK: change   LONG: back",
  )
  @test.assert_eq(
    ui_text_with(ui_text_settings_hint, 1, 0),
    "LONG: cancel / back",
  )
}

///|
test "diagnostic wording splits into status, progress and detail" {
  @test.assert_eq(
    ui_text_with(ui_text_diagnostic_status, diagnostic_status_running, 0),
    "Checking...",
  )
  @test.assert_eq(
    ui_text_with(ui_text_diagnostic_status, diagnostic_status_passed, 0),
    "PASS",
  )
  @test.assert_eq(
    ui_text_with(ui_text_diagnostic_status, diagnostic_status_cancelled, 0),
    "Canceled",
  )
  @test.assert_eq(
    ui_text_with(ui_text_diagnostic_status, diagnostic_status_failed, 0),
    "FAIL",
  )
  @test.assert_eq(ui_text_with(ui_text_diagnostic_status, 9, 0), "")

  @test.assert_eq(
    ui_text_with(ui_text_diagnostic_progress, 8, 32),
    "8 / 32 samples",
  )

  @test.assert_eq(
    ui_diagnostic_detail(diagnostic_status_running, 0, 32, 0, 0),
    "No samples are stored",
  )
  @test.assert_eq(
    ui_diagnostic_detail(diagnostic_status_passed, 32, 32, 32, 0),
    "32 / 32 passed",
  )
  @test.assert_eq(
    ui_diagnostic_detail(diagnostic_status_cancelled, 7, 32, 7, 0),
    "Stopped after 7 samples",
  )
  @test.assert_eq(
    ui_diagnostic_detail(diagnostic_status_failed, 9, 32, 9, 4),
    "9 passed  Error 4",
  )
  @test.assert_eq(ui_diagnostic_detail(9, 0, 32, 0, 0), "")
}

///|
// 每个已定义的文案种类都要出句子：新增种类忘了填表、或代号错位，都会在这里红。
// 表里的代号必须与下标一致，因此同时校验了"种类编号连续且齐全"。
test "every declared text kind renders something with representative arguments" {
  let samples : Array[(Int, Int, Int)] = [
    (ui_text_param_label, parameter_random_length, 10),
    (ui_text_battery, 77, 0),
    (ui_text_battery_unavailable, 0, 0),
    (ui_text_ble_status, ble_keyboard_connected, 0),
    (ui_text_send_button, 0, 0),
    (ui_text_result_failure, 0, 0),
    (ui_text_result_done, 0, 0),
    (ui_text_result_placeholder, 0, 0),
    (ui_text_entropy, 52, 0),
    (ui_text_generate_button, 0, 0),
    (ui_text_settings_name, 0, 0),
    (ui_text_settings_value, 0, 0),
    (ui_text_settings_hint, 0, 0),
    (ui_text_diagnostic_status, diagnostic_status_running, 0),
    (ui_text_diagnostic_progress, 0, 32),
  ]
  @test.assert_eq(samples.length(), ui_text_count)
  let mut index = 0
  for sample in samples {
    @test.assert_eq(sample.0, index)
    @test.assert_eq(
      ui_text_with(sample.0, sample.1, sample.2).length() > 0,
      true,
    )
    index = index + 1
  }
  // 越界种类是空串，不是越界读表。
  @test.assert_eq(ui_text_with(ui_text_count, 0, 0), "")
  @test.assert_eq(ui_text_with(-1, 0, 0), "")
}
