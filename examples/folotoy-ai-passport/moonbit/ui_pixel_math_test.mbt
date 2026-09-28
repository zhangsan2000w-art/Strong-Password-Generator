///|
// 眨眼窗的边界逐点钉住：周期 2000ms、过渡窗 [1650, 1800)。原 C 测试只抽了
// 1700/1850 两点，这里把两侧的边界值都补上，改周期或改窗口宽度都会红。
test "blink frame covers exactly the transition window" {
  @test.assert_eq(ui_pixel_blink_frame(0), false)
  @test.assert_eq(ui_pixel_blink_frame(1649), false)
  @test.assert_eq(ui_pixel_blink_frame(1650), true)
  @test.assert_eq(ui_pixel_blink_frame(1700), true)
  @test.assert_eq(ui_pixel_blink_frame(1799), true)
  @test.assert_eq(ui_pixel_blink_frame(1800), false)
  @test.assert_eq(ui_pixel_blink_frame(1850), false)
  @test.assert_eq(ui_pixel_blink_frame(1999), false)
}

///|
// 相位按 2000ms 回绕：第二轮与第三轮的第 1650..1799 毫秒同样处于过渡帧。
test "blink phase repeats every period" {
  @test.assert_eq(ui_pixel_blink_frame(2000), false)
  @test.assert_eq(ui_pixel_blink_frame(2000 + 1650), true)
  @test.assert_eq(ui_pixel_blink_frame(2000 + 1799), true)
  @test.assert_eq(ui_pixel_blink_frame(2 * 2000 + 1800), false)
}

///|
// 大毫秒计数（远超 32 位、且是周期的整数倍）不改变判定，正是换成 UInt64
// 的意义：uint32_t 计数回绕后同一时刻会算错。
test "blink frame is periodic for large millisecond counts" {
  let base : UInt64 = 1_000_000_000
  @test.assert_eq(base % 2000, 0)
  @test.assert_eq(ui_pixel_blink_frame(base), false)
  @test.assert_eq(ui_pixel_blink_frame(base + 1650), true)
  @test.assert_eq(ui_pixel_blink_frame(base + 1799), true)
  @test.assert_eq(ui_pixel_blink_frame(base + 1800), false)
}

///|
test "jump offsets match the documented curve and clamp out of range" {
  @test.assert_eq(ui_pixel_jump_offset(0), 0)
  @test.assert_eq(ui_pixel_jump_offset(1), -3)
  @test.assert_eq(ui_pixel_jump_offset(2), -5)
  @test.assert_eq(ui_pixel_jump_offset(3), -3)
  @test.assert_eq(ui_pixel_jump_offset(4), 0)
  @test.assert_eq(ui_pixel_jump_offset(5), 0)
  @test.assert_eq(ui_pixel_jump_offset(99), 0)
  @test.assert_eq(ui_pixel_jump_offset(-1), 0)
}
