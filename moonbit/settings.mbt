///|
/// Compact settings state. MoonBit owns focus and value transitions while C
/// owns rendering and persistence.
let settings_selected_shift : Int = 0

///|
let settings_theme_shift : Int = 3

///|
let settings_sound_shift : Int = 4

///|
let settings_policy_profile_shift : Int = 5

///|
let settings_exclude_ambiguous_shift : Int = 7

///|
let settings_action_shift : Int = 8

///|
pub let settings_option_theme : Int = 0

///|
pub let settings_option_sound : Int = 1

///|
pub let settings_option_policy_profile : Int = 2

///|
pub let settings_option_exclude_ambiguous : Int = 3

///|
pub let settings_option_self_check : Int = 4

///|
pub let settings_option_count : Int = 5

///|
pub let settings_action_none : Int = 0

///|
pub let settings_action_start_self_check : Int = 1

///|
fn settings_field(state : UInt64, shift : Int, mask : Int) -> Int {
  ((state >> shift) & mask.to_uint64()).to_int()
}

///|
fn settings_set_field(
  state : UInt64,
  shift : Int,
  mask : Int,
  value : Int,
) -> UInt64 {
  let shifted_mask = mask.to_uint64() << shift
  (state & shifted_mask.lnot()) |
  ((value.to_uint64() & mask.to_uint64()) << shift)
}

///|
pub fn settings_initial(
  theme : Int,
  sound_enabled : Int,
  policy_profile : Int,
  exclude_ambiguous : Int,
) -> UInt64 {
  let mut state = 0UL
  state = settings_set_field(
    state,
    settings_theme_shift,
    1,
    if theme == theme_sky {
      1
    } else {
      0
    },
  )
  state = settings_set_field(
    state,
    settings_sound_shift,
    1,
    if sound_enabled != 0 {
      1
    } else {
      0
    },
  )
  state = settings_set_field(
    state,
    settings_policy_profile_shift,
    3,
    normalize_policy_profile(policy_profile),
  )
  settings_set_field(
    state,
    settings_exclude_ambiguous_shift,
    1,
    if exclude_ambiguous != 0 {
      1
    } else {
      0
    },
  )
}

///|
pub fn settings_handle_input(original : UInt64, input : Int) -> UInt64 {
  let state = settings_set_field(
    original, settings_action_shift, 3, settings_action_none,
  )
  if input == input_up || input == input_down {
    let selected = settings_field(state, settings_selected_shift, 7)
    let delta = if input == input_up { settings_option_count - 1 } else { 1 }
    return settings_set_field(
      state,
      settings_selected_shift,
      7,
      (selected + delta) % settings_option_count,
    )
  }
  if input == input_ok {
    let selected = settings_field(state, settings_selected_shift, 7)
    if selected == settings_option_theme {
      return settings_set_field(
        state,
        settings_theme_shift,
        1,
        1 - settings_field(state, settings_theme_shift, 1),
      )
    }
    if selected == settings_option_sound {
      return settings_set_field(
        state,
        settings_sound_shift,
        1,
        1 - settings_field(state, settings_sound_shift, 1),
      )
    }
    if selected == settings_option_policy_profile {
      return settings_set_field(
        state,
        settings_policy_profile_shift,
        3,
        (settings_field(state, settings_policy_profile_shift, 3) + 1) %
        policy_profile_count,
      )
    }
    if selected == settings_option_self_check {
      return settings_set_field(
        state, settings_action_shift, 3, settings_action_start_self_check,
      )
    }
    return settings_set_field(
      state,
      settings_exclude_ambiguous_shift,
      1,
      1 - settings_field(state, settings_exclude_ambiguous_shift, 1),
    )
  }
  state
}

///|
pub fn settings_map_button_event(button : Int, event : Int) -> Int {
  if button == button_ok && event == button_event_long {
    return input_ok_long
  }
  if event != button_event_click {
    return input_ignored
  }
  if button == button_up {
    return input_up
  }
  if button == button_down {
    return input_down
  }
  if button == button_ok {
    return input_ok
  }
  input_ignored
}

///|
pub fn settings_selected(state : UInt64) -> Int {
  settings_field(state, settings_selected_shift, 7)
}

///|
pub fn settings_action(state : UInt64) -> Int {
  settings_field(state, settings_action_shift, 3)
}

///|
pub fn settings_theme(state : UInt64) -> Int {
  settings_field(state, settings_theme_shift, 1)
}

///|
pub fn settings_sound_enabled(state : UInt64) -> Int {
  settings_field(state, settings_sound_shift, 1)
}

///|
pub fn settings_policy_profile(state : UInt64) -> Int {
  settings_field(state, settings_policy_profile_shift, 3)
}

///|
pub fn settings_exclude_ambiguous(state : UInt64) -> Int {
  settings_field(state, settings_exclude_ambiguous_shift, 1)
}

///|
// 持久化配置的清洗入口。NVS 里的字节可能来自旧版本固件、写坏的值或手工改动，
// 必须收敛到合法枚举。这套规则原先在 main/settings_store.c 里写了两遍且边界
// 不一致（加载路径只查上界、setter 查上下界），而策略档位在 policy_profile.mbt
// 里还有第三份正确实现。这里收成唯一入口：C 侧两条路径都调它，
// 策略档位直接复用 normalize_policy_profile，不再各写各的。
#export_name("passport_moonbit_settings_sanitize_theme")
pub fn settings_sanitize_theme(raw : Int) -> Int {
  if raw == theme_sky { theme_sky } else { theme_cyber }
}

///|
#export_name("passport_moonbit_settings_sanitize_policy_profile")
pub fn settings_sanitize_policy_profile(raw : Int) -> Int {
  normalize_policy_profile(raw)
}

///|
// 布尔型设置：只有 0 算关，其余一律算开，与 C 侧原本的 != 0 语义一致。
#export_name("passport_moonbit_settings_sanitize_flag")
pub fn settings_sanitize_flag(raw : Int) -> Int {
  if raw != 0 { 1 } else { 0 }
}
