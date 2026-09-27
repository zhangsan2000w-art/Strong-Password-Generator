// FAP_SCREENSHOT_V1 串口截屏协议的核心逻辑：命令匹配状态机、协议头构建、
// 快照几何校验。纯逻辑、不依赖 ESP-IDF/LVGL，可在主机上用 moon test 单测；
// 硬件 IO（USB-CDC 驱动、LVGL snapshot、分块发送）留在 main/fap_screenshot.c。
// 协议与坑点见 docs/reference/y2lin/serial-screenshot-protocol.md。

///|
// 主机发送的完整命令（含结尾换行符）。
pub let command : String = "FAP_SCREENSHOT_V1\n"

///|
let header_prefix : String = "FAP_SCREENSHOT_V1"

///|
let pixel_format : String = "RGB565LE"

///|
let line_feed : Int = 10

///|
let carriage_return : Int = 13

///|
let digit_zero : Int = 48

///|
let space : Int = 32

///|
// 命令串长度（含结尾换行符）。
#export_name("passport_moonbit_screenshot_command_length")
pub fn screenshot_command_length() -> Int {
  command.length()
}

///|
// 匹配状态：已连续命中命令前缀的字节数。
#export_name("passport_moonbit_screenshot_matcher_initial")
pub fn screenshot_matcher_initial() -> Int {
  0
}

///|
// 送入一个字节，返回下一个状态。
// 返回 command_length() 表示命中一次（调用方处理完须回到 initial，
// 这里已确保残留字节不会立即重触发）。
// 语义与参考实现的滑动窗口一致：先匹配、后复位——行结束符（\r 或 \n）
// 会清空窗口，除非该 \n 恰好补完整条命令；这样 Windows 终端工具吞掉或
// 补全换行都不会漏检或误触发。命令串首字符 'F' 全串唯一（无自重叠前缀），
// 失配时最多只需回退到状态 1。
#export_name("passport_moonbit_screenshot_matcher_feed")
pub fn screenshot_matcher_feed(state : Int, byte : Int) -> Int {
  let current = if state < 0 || state >= command.length() {
    0
  } else {
    state
  }
  if byte == carriage_return {
    return 0
  }
  if byte == line_feed {
    return if current == command.length() - 1 {
      command.length()
    } else {
      0
    }
  }
  let expected = match command.get_char(current) {
    Some(ch) => ch.to_int()
    None => 0
  }
  let first = match command.get_char(0) {
    Some(ch) => ch.to_int()
    None => 0
  }
  if byte == expected {
    current + 1
  } else if byte == first {
    1
  } else {
    0
  }
}

///|
fn emit_text(text : String, put : (Int) -> Unit) -> Unit {
  for ch in text {
    put(ch.to_int())
  }
}

///|
fn emit_uint(value : Int, put : (Int) -> Unit) -> Unit {
  if value <= 0 {
    put(digit_zero)
    return
  }
  let digits : Array[Int] = []
  let mut rest = value
  while rest > 0 {
    digits.push(digit_zero + rest % 10)
    rest = rest / 10
  }
  let mut index = digits.length() - 1
  while index >= 0 {
    put(digits[index])
    index -= 1
  }
}

///|
// 构建 FAP_SCREENSHOT_V1 <w> <h> RGB565LE <bytes>\n 协议头。
// put 收到的就是应答的原始字节，返回总字节数。
pub fn screenshot_header_build_with(
  width : Int,
  height : Int,
  payload : Int,
  put : (Int) -> Unit,
) -> Int {
  let counter : Array[Int] = [0]
  let emit = fn(ch : Int) -> Unit {
    counter[0] = counter[0] + 1
    put(ch)
  }
  emit_text(header_prefix, emit)
  emit(space)
  emit_uint(width, emit)
  emit(space)
  emit_uint(height, emit)
  emit(space)
  emit_text(pixel_format, emit)
  emit(space)
  emit_uint(payload, emit)
  emit(line_feed)
  counter[0]
}

///|
extern "C" fn platform_screenshot_header_reset() -> Unit =
  "passport_screenshot_header_reset"

///|
extern "C" fn platform_screenshot_header_push(ch : Int) -> Bool =
  "passport_screenshot_header_push"

///|
// 面向固件的协议头构建：字节经 platform 回调落入 C 侧缓冲，
// 返回应发送的字节数（C 侧须核对自己收集到的长度一致）。
#export_name("passport_moonbit_screenshot_header_build")
pub fn screenshot_header_build(width : Int, height : Int, payload : Int) -> Int {
  platform_screenshot_header_reset()
  screenshot_header_build_with(width, height, payload, fn(ch) {
    let _ = platform_screenshot_header_push(ch)
  })
}

///|
// 快照几何校验：只放行与期望面板一致的紧凑满屏 RGB565。
// width/height/stride/data_size 来自 LVGL 快照缓冲，
// expected_width/expected_height 由 C 侧传 BSP_LCD_W/BSP_LCD_H（事实只在 bsp_pins.h）。
#export_name("passport_moonbit_screenshot_geometry_ok")
pub fn screenshot_geometry_ok(
  width : Int,
  height : Int,
  stride : Int,
  data_size : Int,
  expected_width : Int,
  expected_height : Int,
) -> Int {
  if width != expected_width || height != expected_height {
    return 0
  }
  if stride != expected_width * 2 {
    return 0
  }
  if data_size < expected_width * expected_height * 2 {
    return 0
  }
  1
}
