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
test "band feed accepts contiguous full-width tight-packed bands" {
  let mut rows = screenshot_band_initial()
  let mut index = 0
  while index < 320 / 20 {
    rows = screenshot_band_feed(rows, 0, index * 20, 240, 20, 240 * 20 * 2, 240, 320)
    @test.assert_eq(rows, (index + 1) * 20)
    index += 1
  }
  @test.assert_eq(rows, 320)
  @test.assert_eq(screenshot_band_complete(rows, 320), 1)
}

///|
test "band feed accepts ragged band heights as long as they tile" {
  let mut rows = screenshot_band_initial()
  rows = screenshot_band_feed(rows, 0, 0, 240, 20, 240 * 20 * 2, 240, 320)
  rows = screenshot_band_feed(rows, 0, 20, 240, 300, 240 * 300 * 2, 240, 320)
  @test.assert_eq(rows, 320)
}

///|
test "band feed rejects a gap in the row coverage" {
  let rows = screenshot_band_feed(20, 0, 60, 240, 20, 240 * 20 * 2, 240, 320)
  @test.assert_eq(rows, -band_gap)
}

///|
test "band feed rejects an overlapping or replayed band" {
  let rows = screenshot_band_feed(100, 0, 80, 240, 20, 240 * 20 * 2, 240, 320)
  @test.assert_eq(rows, -band_overlap)
}

///|
test "band feed rejects geometry that is not a full-width tight-packed strip" {
  // 未横向铺满（x != 0 或 w != 面板宽）
  @test.assert_eq(
    screenshot_band_feed(0, 8, 0, 240, 20, 240 * 20 * 2, 240, 320),
    -band_bad_geometry,
  )
  @test.assert_eq(
    screenshot_band_feed(0, 0, 0, 239, 20, 239 * 20 * 2, 240, 320),
    -band_bad_geometry,
  )
  // 字节数与 w*h*2 不符（带 stride 填充或色深不对都不放行）
  @test.assert_eq(
    screenshot_band_feed(0, 0, 0, 240, 20, 240 * 20 * 2 + 4, 240, 320),
    -band_bad_geometry,
  )
  @test.assert_eq(
    screenshot_band_feed(0, 0, 0, 240, 20, 240 * 20, 240, 320),
    -band_bad_geometry,
  )
  // 零尺寸
  @test.assert_eq(
    screenshot_band_feed(0, 0, 0, 240, 0, 0, 240, 320),
    -band_bad_geometry,
  )
}

///|
test "band feed refuses to run past the last panel row" {
  let rows = screenshot_band_feed(310, 0, 310, 240, 20, 240 * 20 * 2, 240, 320)
  @test.assert_eq(rows, -band_overflow)
}

///|
test "capture is incomplete until every row is covered" {
  @test.assert_eq(screenshot_band_complete(0, 320), 0)
  @test.assert_eq(screenshot_band_complete(300, 320), 0)
  @test.assert_eq(screenshot_band_complete(320, 320), 1)
}

///|
fn produce_bands(count : Int) -> Unit {
  let mut index = 0
  while index < count {
    session_produced(240 * 20 * 2)
    index += 1
  }
}

///|
test "session requires a produced band before the header may go out" {
  let need = session_begin(240, 320)
  @test.assert_eq(need, 153600)
  @test.assert_eq(session_header_allowed(), 0)
  session_produced(9600)
  @test.assert_eq(session_header_allowed(), 1)
}

///|
// 这条钉住双槽环形缓冲下最容易犯的错：抽头会跑在发送任务前面，
// 用"已产出"判完成会在尾带还没写出去时就收工，静默丢图。
test "session is not done while produced bytes outrun sent bytes" {
  session_begin(240, 320) |> ignore
  // 抽头已经把 16 条带全部产出，发送任务还一条都没写
  produce_bands(16)
  let mut index = 0
  while index < 15 {
    // 已产出 153600、已写出 index*9600：只要写出落后于产出，就必须继续发，
    // 哪怕产出侧早就铺满整屏。用"已产出"判完成就是在这里翻车的。
    @test.assert_eq(session_action(), action_send_band)
    session_band_sent(9600) |> ignore
    index += 1
  }
  @test.assert_eq(session_result(), result_incomplete)
  // 最后一条带写出去才算完成
  @test.assert_eq(session_band_sent(9600), action_done)
  @test.assert_eq(session_result(), result_ok)
}

///|
test "session waits when everything produced so far has been sent" {
  session_begin(240, 320) |> ignore
  produce_bands(5)
  let mut index = 0
  while index < 5 {
    session_band_sent(9600) |> ignore
    index += 1
  }
  @test.assert_eq(session_action(), action_wait)
  @test.assert_eq(session_result(), result_incomplete)
}

///|
test "session aborts on the first fault and keeps its reason" {
  session_begin(240, 320) |> ignore
  produce_bands(1)
  session_note_fault(result_band_fault)
  @test.assert_eq(session_action(), action_abort)
  @test.assert_eq(session_result(), result_band_fault)
  // 收尾时的超时不能把真正的故障原因冲掉
  session_note_fault(result_timed_out)
  @test.assert_eq(session_result(), result_band_fault)
  @test.assert_eq(session_header_allowed(), 0)
}

///|
test "session refuses to call an over-sent frame done" {
  session_begin(240, 320) |> ignore
  produce_bands(16)
  let mut index = 0
  while index < 16 {
    session_band_sent(9600) |> ignore
    index += 1
  }
  @test.assert_eq(session_band_sent(9600), action_abort)
}

///|
test "result names are emitted for every documented code" {
  let collect_name = fn(result : Int) -> String {
    let buffer : Array[Int] = []
    session_result_name_with(result, fn(ch) { buffer.push(ch) })
    let builder = StringBuilder()
    for code in buffer {
      match code.to_char() {
        Some(ch) => builder.write_char(ch)
        None => builder.write_char('?')
      }
    }
    builder.to_string()
  }
  @test.assert_eq(collect_name(result_ok), "ok")
  @test.assert_eq(collect_name(result_band_fault), "band-fault")
  @test.assert_eq(collect_name(result_stalled), "stalled")
  @test.assert_eq(collect_name(result_timed_out), "timed-out")
  @test.assert_eq(collect_name(result_transport), "transport")
  @test.assert_eq(collect_name(result_incomplete), "incomplete")
  @test.assert_eq(collect_name(result_no_lock), "no-lvgl-lock")
  @test.assert_eq(collect_name(99), "unknown")
}

///|
test "band byte order contract stays little-endian on the wire" {
  @test.assert_eq(screenshot_band_swap_pairs(), 1)
}

///|
// C 侧要按 action 分支，必须携带一份同样的编号。这里把编号钉住：
// 改动这里的数值会让本测试失败，提醒同步 main/fap_screenshot.c 的常量块。
test "action codes match the C adapter constants" {
  @test.assert_eq(action_wait, 0)
  @test.assert_eq(action_send_band, 2)
  @test.assert_eq(action_done, 3)
  @test.assert_eq(action_abort, 4)
}

///|
// 真机现象：整屏重绘后的第二个刷新周期会从 y=0 再画一遍，抽头若继续判定
// 就会把已经攒齐的一帧整个作废（rows=320/320 却报 band-fault）。
test "session stops accepting bands once the whole frame is produced" {
  session_begin(240, 320) |> ignore
  @test.assert_eq(session_accepting(), 1)
  produce_bands(15)
  @test.assert_eq(session_accepting(), 1)
  session_produced(9600)
  @test.assert_eq(session_accepting(), 0)
}

///|
test "session stops accepting bands after a fault" {
  session_begin(240, 320) |> ignore
  session_note_band_fault()
  @test.assert_eq(session_accepting(), 0)
}
