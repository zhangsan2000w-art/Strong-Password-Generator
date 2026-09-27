///|
fn feed_text(state : Int, text : String) -> Int {
  let mut current = state
  for ch in text {
    current = screenshot_matcher_feed(current, ch.to_int())
  }
  current
}

///|
fn collect(
  width : Int,
  height : Int,
  payload : Int,
) -> (String, Int) {
  let buffer : Array[Int] = []
  let count = screenshot_header_build_with(width, height, payload, fn(ch) {
    buffer.push(ch)
  })
  let builder = StringBuilder()
  for code in buffer {
    match code.to_char() {
      Some(ch) => builder.write_char(ch)
      None => builder.write_char('?')
    }
  }
  (builder.to_string(), count)
}

///|
test "matcher accepts the exact command at the final newline" {
  let mut state = screenshot_matcher_initial()
  let mut fed = 0
  for ch in command {
    state = screenshot_matcher_feed(state, ch.to_int())
    fed = fed + 1
    if fed < command.length() {
      @test.assert_eq(state == command.length(), false)
    }
  }
  @test.assert_eq(state, command.length())
  @test.assert_eq(command.length(), 18)
}

///|
test "matcher stays silent without the trailing newline" {
  @test.assert_eq(
    feed_text(screenshot_matcher_initial(), "FAP_SCREENSHOT_V1"),
    command.length() - 1,
  )
  @test.assert_eq(
    feed_text(screenshot_matcher_initial(), "FAP_SCREENSHOT_V1X\n"),
    0,
  )
}

///|
test "matcher ignores leading garbage and resets on terminators" {
  let mut state = screenshot_matcher_initial()
  state = feed_text(state, "hello\r\n")
  @test.assert_eq(state, 0)
  state = feed_text(state, command)
  @test.assert_eq(state, command.length())
}

///|
test "matcher does not re-trigger on residual bytes after a match" {
  let state = feed_text(screenshot_matcher_initial(), command)
  @test.assert_eq(state, command.length())
  // 调用方处理完命中后回到 initial；残留字节不应再次命中。
  let mut resumed = screenshot_matcher_feed(screenshot_matcher_initial(), 0x20)
  resumed = feed_text(resumed, "FAP_SCREENSHOT_V1")
  @test.assert_eq(resumed, command.length() - 1)
}

///|
test "matcher rejects commands split by a terminator" {
  @test.assert_eq(
    feed_text(screenshot_matcher_initial(), "FAP_\nSCREENSHOT_V1\n"),
    0,
  )
}

///|
test "matcher preserves substring semantics across repeated prefixes" {
  // "FF..." 会把第二个 F 当作新的命令前缀继续累积。
  let mut state = screenshot_matcher_feed(
    screenshot_matcher_initial(),
    command.get_char(0).unwrap().to_int(),
  )
  state = screenshot_matcher_feed(
    state,
    command.get_char(0).unwrap().to_int(),
  )
  @test.assert_eq(state, 1)
  state = feed_text(state, "AP_SCREENSHOT_V1\n")
  @test.assert_eq(state, command.length())
}

///|
test "header build emits the documented protocol header" {
  let (text, count) = collect(240, 320, 240 * 320 * 2)
  @test.assert_eq(text, "FAP_SCREENSHOT_V1 240 320 RGB565LE 153600\n")
  @test.assert_eq(count, text.length())
}

///|
test "header build formats arbitrary sizes" {
  let (text, count) = collect(128, 160, 40960)
  @test.assert_eq(text, "FAP_SCREENSHOT_V1 128 160 RGB565LE 40960\n")
  @test.assert_eq(count, 41)
}

///|
test "geometry check accepts only tight-packed full-screen snapshots" {
  @test.assert_eq(screenshot_geometry_ok(240, 320, 480, 153600, 240, 320), 1)
  @test.assert_eq(screenshot_geometry_ok(239, 320, 480, 153600, 240, 320), 0)
  @test.assert_eq(screenshot_geometry_ok(240, 319, 480, 153600, 240, 320), 0)
  @test.assert_eq(screenshot_geometry_ok(240, 320, 484, 153600, 240, 320), 0)
  @test.assert_eq(screenshot_geometry_ok(240, 320, 480, 153599, 240, 320), 0)
}
