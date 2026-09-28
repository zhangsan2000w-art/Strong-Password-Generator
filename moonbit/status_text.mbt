///|
// 结果区状态文案的选择与拼装。
//
// 这段逻辑原本躺在 main/password_app.c 的静态字符串表里。"标准缺少小写"
// 那种半截话就是这么长出来的：策略名和告警片段各存一份、运行时拼接，没有
// 任何地方断言"用户最终看到的那句话"是什么。移到这里的目的是把那句话变成
// 被单测钉住的契约——改措辞会红，拼错前缀也会红。

///|
let profile_names : Array[String] = ["兼容", "标准", "严格"]

///|
// 下标即 security_warning_* 的取值。1/4/5/6 是"相对当前策略"的判定，必须
// 带策略名前缀才知道是谁不满意；2/3 讲的是小写/大写开关本身，整句自足，
// 再拼前缀反而读不通。
let warning_texts : Array[String] = [
  "", "长度过短", "生成关闭小写", "生成关闭大写", "缺少数字", "缺少符号",
  "配置无效",
]

///|
let warning_needs_profile : Array[Bool] = [
  false, true, false, false, true, true, true,
]

///|
// 越界的策略取值回落到"标准"，与 state.mbt 的 normalize 保持一致。
pub fn status_profile_name(profile : Int) -> String {
  if profile >= 0 && profile < profile_names.length() {
    profile_names[profile]
  } else {
    profile_names[1]
  }
}

///|
// UTF-8 编码。MoonBit 的 Char#to_int() 给的是 Unicode 码点，而固件的显示
// 缓冲要的是 UTF-8 字节；标准库这一版没有现成编码器，手写的部分逐范围断言。
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
// 组装状态文案：字节经 put 送出，返回字节数。
pub fn status_text_build_with(
  profile : Int,
  warning : Int,
  put : (Int) -> Unit,
) -> Int {
  let mut count = 0
  if warning > 0 && warning < warning_texts.length() {
    if warning_needs_profile[warning] {
      count = count + emit_text_utf8(status_profile_name(profile), put)
      count = count + emit_text_utf8(" ", put)
    }
    count = count + emit_text_utf8(warning_texts[warning], put)
  } else {
    count = count + emit_text_utf8("策略 ", put)
    count = count + emit_text_utf8(status_profile_name(profile), put)
  }
  count
}

///|
extern "C" fn platform_status_text_reset() -> Unit =
  "passport_status_text_reset"

///|
extern "C" fn platform_status_text_push(ch : Int) -> Bool =
  "passport_status_text_push"

///|
// 面向固件的文案构建：字节经 platform 回调落到 C 侧缓冲，返回应写入的字节数
// （C 侧须核对自己收集到的长度一致，长度不符就保留上一次文案）。
#export_name("passport_moonbit_status_text_build")
pub fn status_text_build(profile : Int, warning : Int) -> Int {
  platform_status_text_reset()
  status_text_build_with(profile, warning, fn(ch) {
    let _ = platform_status_text_push(ch)
  })
}
