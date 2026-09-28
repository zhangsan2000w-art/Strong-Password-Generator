///|
// 像素 UI 的纯动画数学：吉祥物的眨眼相位与跳跃曲线。
//
// 这两条曲线原先在 main/ui_pixel_math.c，唯一的使用者是它自己的主机 C 测试：
// main/ui_pixel.c 里的眨眼动画是 70+70ms、每 1700ms 重复的另一组参数，跳跃动画
// 也是单段 lv_anim（y → y-5），都不调用这两个函数。因此这次迁移不改变固件行为，
// 只是把这段被测逻辑收进 MoonBit 核心；passport_moonbit_ui_pixel_* 导出保留，
// 供界面层将来采用。返回值语义与原 C 实现逐位一致（1/0 与表内偏移）。

///|
// 眨眼周期 2000ms，仅 [1650, 1800) 这 150ms 属于过渡帧，其余时间眼睛保持睁开。
let blink_period_ms : UInt64 = 2000

///|
let blink_start_ms : UInt64 = 1650

///|
let blink_end_ms : UInt64 = 1800

///|
// 跳跃帧序列：相对基准 y 的偏移，越界一律 0。
let ui_pixel_jump_offsets : Array[Int] = [0, -3, -5, -3, 0]

///|
// 该时刻是否处于眨眼过渡帧。用 UInt64 承接 lv_tick 的毫秒计数：原 C 实现用
// uint32_t，计数回绕后取模会得到负相位，UInt64 下相位始终是 0..1999。
pub fn ui_pixel_blink_frame(elapsed_ms : UInt64) -> Bool {
  let phase = elapsed_ms % blink_period_ms
  phase >= blink_start_ms && phase < blink_end_ms
}

///|
// 第 frame 帧的跳跃偏移；越界（含负数）返回 0。
pub fn ui_pixel_jump_offset(frame : Int) -> Int {
  if frame >= 0 && frame < ui_pixel_jump_offsets.length() {
    ui_pixel_jump_offsets[frame]
  } else {
    0
  }
}
