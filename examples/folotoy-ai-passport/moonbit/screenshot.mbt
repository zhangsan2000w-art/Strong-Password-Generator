// FAP_SCREENSHOT_V1 串口截屏协议的核心逻辑：命令匹配状态机、协议头构建、
// 条带流式捕获的带序状态机。纯逻辑、不依赖 ESP-IDF/LVGL，可在主机上用
// moon test 单测；硬件 IO（USB-CDC 驱动、面板 flush 抽头、分块发送）留在
// main/fap_screenshot.c。协议与坑点见
// docs/reference/y2lin/serial-screenshot-protocol.md。

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
// 条带流式捕获的带序状态机。
//
// 本板（ESP32-C3，无 PSRAM）拿不到 150KB 连续内部 RAM：常规 RAM 堆区
// 上限 118,848 字节，retention 区是另一个区，单次分配跨不过去；而蓝牙
// 运行时还要占约 115KB。所以整屏快照不再一次性成型，而是从面板 flush
// 处按条带旁路收集，逐带上传。线上字节流与整屏缓冲时完全一致，主机端
// 不需要知道区别。
//
// C 侧只负责搬字节，判定全在这里：带必须从 x=0 起、宽度等于面板宽度、
// 字节数恰为 w*h*2 的紧凑 RGB565LE，并且必须与已覆盖行数无缝相接
// （不缺口、不重叠）。任何一条不成立都返回负错误码，由 C 侧作废本次
// 捕获——宁可让主机超时重采，也不发一张错位的图。
pub let band_ok : Int = 0

///|
pub let band_bad_geometry : Int = 1

///|
pub let band_gap : Int = 2

///|
pub let band_overlap : Int = 3

///|
pub let band_overflow : Int = 4

///|
#export_name("passport_moonbit_screenshot_band_initial")
pub fn screenshot_band_initial() -> Int {
  0
}

///|
// 送入一条刚刷到面板上的条带。
// rows：已覆盖的行数（初值 screenshot_band_initial()）
// x/y/w/h/byte_len：本带的矩形与字节数，来自面板 draw_bitmap 实参
// 返回 >=0 表示新的已覆盖行数；<0 表示 -错误码，本带未被计入。
#export_name("passport_moonbit_screenshot_band_feed")
pub fn screenshot_band_feed(
  rows : Int,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  byte_len : Int,
  expected_width : Int,
  expected_height : Int,
) -> Int {
  if w <= 0 || h <= 0 {
    return -band_bad_geometry
  }
  // 条带必须横向铺满：本板无旋转/镜像，LVGL 的部分刷新按整行下发。
  if x != 0 || w != expected_width {
    return -band_bad_geometry
  }
  if byte_len != w * h * 2 {
    return -band_bad_geometry
  }
  if y < rows {
    return -band_overlap
  }
  if y > rows {
    return -band_gap
  }
  let next = rows + h
  if next > expected_height {
    return -band_overflow
  }
  next
}

///|
// 整屏是否已按行铺满（缺最后几行不算完成）。
#export_name("passport_moonbit_screenshot_band_complete")
pub fn screenshot_band_complete(rows : Int, expected_height : Int) -> Int {
  if rows == expected_height { 1 } else { 0 }
}

///|
// 条带字节序策略：面板抽头拿到的像素要不要成对交换。
//
// esp_lvgl_port 在把条带交给面板之前，会为大端 SPI 屏做原地
// lv_draw_sw_rgb565_swap，而协议声明的是 RGB565LE，所以抽头必须换回来。
// 把这个约定放在这里而不是 C 的拷贝循环里，是为了让它可被单测钉住：
// 换错一次，主机得到的就是一整张红蓝互换的图，而构建与真机都不会报错。
#export_name("passport_moonbit_screenshot_band_swap_pairs")
pub fn screenshot_band_swap_pairs() -> Int {
  1
}

///|
// ---- 捕获会话记账 ----
//
// 同一时刻只会有一个捕获会话：本板是 unicore 固件，且捕获窗口由 LVGL 锁
// 与串口写窗口串行化。状态放在包内可变数组里，C 侧只报告事件（一条带已
// 产出、一条带已写出、超时、传输断开）并询问"下一步做什么"。
//
// "何时算一帧完成"这条规则必须留在这里而不是 C 里：C 侧有两个进度计数器
// ——抽头已产出的字节数、发送任务已写出的字节数。双槽环形缓冲下抽头会跑在
// 发送任务前面，用"已产出"判完成会在最后一帧还没写出去时就收工，静默丢掉
// 尾带。这类错误在真机上表现为"图像偶尔少一截"，最难查，所以钉成单测。
let session : Array[Int] = [0, 0, 0, 0]
// [0] 整帧需要字节数 [1] 已产出字节数 [2] 已写出字节数 [3] 故障码

///|
pub let action_wait : Int = 0

///|
pub let action_send_band : Int = 2

///|
pub let action_done : Int = 3

///|
pub let action_abort : Int = 4

///|
pub let result_ok : Int = 0

///|
pub let result_band_fault : Int = 1

///|
pub let result_stalled : Int = 2

///|
pub let result_timed_out : Int = 3

///|
pub let result_transport : Int = 4

///|
pub let result_incomplete : Int = 5

///|
pub let result_no_memory : Int = 6

///|
pub let result_header : Int = 7

///|
pub let result_no_lock : Int = 8

///|
// 开始一次会话，返回整帧需要的字节数。
#export_name("passport_moonbit_screenshot_session_begin")
pub fn session_begin(width : Int, height : Int) -> Int {
  session[0] = width * height * 2
  session[1] = 0
  session[2] = 0
  session[3] = 0
  session[0]
}

///|
// 抽头已校验并暂存了一条带。
#export_name("passport_moonbit_screenshot_session_produced")
pub fn session_produced(bytes : Int) -> Unit {
  session[1] = session[1] + bytes
}

///|
// 记录故障。以第一个故障为准，后续故障（例如收尾时的等待超时）不覆盖它，
// 否则诊断会把"带序错位"报成"超时"，把真正的线索丢掉。
#export_name("passport_moonbit_screenshot_session_note_fault")
pub fn session_note_fault(code : Int) -> Unit {
  if session[3] == 0 {
    session[3] = code
  }
}

///|
// 故障词汇也留在这里：C 侧只报告"发生了哪种事"，不需要知道任何编号，
// 因此不会出现两边各写一份魔数、其中一份悄悄改掉的局面。
#export_name("passport_moonbit_screenshot_session_note_band_fault")
pub fn session_note_band_fault() -> Unit {
  session_note_fault(result_band_fault)
}

///|
#export_name("passport_moonbit_screenshot_session_note_stalled")
pub fn session_note_stalled() -> Unit {
  session_note_fault(result_stalled)
}

///|
#export_name("passport_moonbit_screenshot_session_note_timed_out")
pub fn session_note_timed_out() -> Unit {
  session_note_fault(result_timed_out)
}

///|
#export_name("passport_moonbit_screenshot_session_note_transport")
pub fn session_note_transport() -> Unit {
  session_note_fault(result_transport)
}

///|
// 环形缓冲申请不到（内部堆碎片化到连 18.75KB 连续块都没有）。
#export_name("passport_moonbit_screenshot_session_note_no_memory")
pub fn session_note_no_memory() -> Unit {
  session_note_fault(result_no_memory)
}

///|
// MoonBit 自己构建的协议头长度对不上，属于实现内部不一致。
#export_name("passport_moonbit_screenshot_session_note_header")
pub fn session_note_header() -> Unit {
  session_note_fault(result_header)
}

///|
// 取不到 LVGL 锁：无法安全地强制整屏重绘，与"等带超时"是两回事。
#export_name("passport_moonbit_screenshot_session_note_no_lock")
pub fn session_note_no_lock() -> Unit {
  session_note_fault(result_no_lock)
}

///|
// 是否允许发协议头：必须已经有第一条带且没有故障。
// 先等首带再发头，整场失败时主机看到的是"设备没应答"，而不是收到头之后
// 干等一堆永远不来的像素。
#export_name("passport_moonbit_screenshot_session_header_allowed")
pub fn session_header_allowed() -> Int {
  if session[3] != 0 {
    return 0
  }
  if session[1] > 0 { 1 } else { 0 }
}

///|
// 抽头是否还应接收新的带：整帧已产出够、或已经故障，就不再收。
//
// 强制整屏重绘之后，LVGL 的下一个刷新周期会从 y=0 再画一遍。若那时抽头还在
// 按带序判定，这第二遍会被当成"重叠"而判故障，把已经攒齐的完整一帧整个作废
// ——真机上就是这个现象：rows=320/320 却报 band-fault，主机只收到 15 条带。
#export_name("passport_moonbit_screenshot_session_accepting")
pub fn session_accepting() -> Int {
  if session[3] != 0 {
    return 0
  }
  if session[1] >= session[0] {
    return 0
  }
  1
}

///|
// 当前该做什么。
#export_name("passport_moonbit_screenshot_session_action")
pub fn session_action() -> Int {
  if session[3] != 0 {
    return action_abort
  }
  if session[2] < session[1] {
    return action_send_band
  }
  if session[2] == session[0] {
    return action_done
  }
  if session[2] > session[0] {
    // 写超量说明产出侧记账错了，宁可不发完。
    return action_abort
  }
  action_wait
}

///|
// 报告"又写出了一条带"，返回写出之后的动作。
#export_name("passport_moonbit_screenshot_session_band_sent")
pub fn session_band_sent(bytes : Int) -> Int {
  session[2] = session[2] + bytes
  session_action()
}

///|
// 会话结果码：没故障时由"写出字节数是否等于整帧"决定。
#export_name("passport_moonbit_screenshot_session_result")
pub fn session_result() -> Int {
  if session[3] != 0 {
    return session[3]
  }
  if session[0] > 0 && session[2] == session[0] {
    result_ok
  } else {
    result_incomplete
  }
}

///|
// 结果码的可读名字，经 platform 回调落到 C 侧缓冲，供诊断日志使用。
pub fn session_result_name_with(result : Int, put : (Int) -> Unit) -> Unit {
  let name = match result {
    0 => "ok"
    1 => "band-fault"
    2 => "stalled"
    3 => "timed-out"
    4 => "transport"
    5 => "incomplete"
    6 => "no-memory"
    7 => "header"
    8 => "no-lvgl-lock"
    _ => "unknown"
  }
  emit_text(name, put)
}

///|
extern "C" fn platform_screenshot_name_reset() -> Unit =
  "passport_screenshot_name_reset"

///|
extern "C" fn platform_screenshot_name_push(ch : Int) -> Bool =
  "passport_screenshot_name_push"

///|
#export_name("passport_moonbit_screenshot_result_name_build")
pub fn session_result_name_build(result : Int) -> Int {
  platform_screenshot_name_reset()
  let counter : Array[Int] = [0]
  session_result_name_with(result, fn(ch) {
    counter[0] = counter[0] + 1
    let _ = platform_screenshot_name_push(ch)
  })
  counter[0]
}
