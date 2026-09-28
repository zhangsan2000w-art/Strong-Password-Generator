///|
fn collect_status(profile : Int, warning : Int) -> Array[Int] raise {
  let buffer : Array[Int] = []
  let count = status_text_build_with(profile, warning, fn(ch) {
    buffer.push(ch)
  })
  @test.assert_eq(count, buffer.length())
  buffer
}

///|
fn encode(text : String) -> Array[Int] raise {
  let buffer : Array[Int] = []
  let count = emit_text_utf8(text, fn(ch) { buffer.push(ch) })
  @test.assert_eq(count, buffer.length())
  buffer
}

///|
fn assert_bytes(actual : Array[Int], expected : Array[Int]) -> Unit raise {
  @test.assert_eq(actual.length(), expected.length())
  let mut index = 0
  while index < expected.length() {
    @test.assert_eq(actual[index], expected[index])
    index = index + 1
  }
}

///|
// 编码器单独用已知向量钉住，避免"用被测函数验证被测函数"。
test "utf8 encoder matches known byte vectors" {
  assert_bytes(encode("A"), [0x41])
  assert_bytes(encode("策略"), [0xE7, 0xAD, 0x96, 0xE7, 0x95, 0xA5])
  assert_bytes(encode("生成关闭小写"), [
    0xE7, 0x94, 0x9F, 0xE6, 0x88, 0x90, 0xE5, 0x85, 0xB3, 0xE9, 0x97, 0xAD,
    0xE5, 0xB0, 0x8F, 0xE5, 0x86, 0x99,
  ])
  assert_bytes(encode("😀"), [0xF0, 0x9F, 0x98, 0x80])
  @test.assert_eq(utf8_byte_count(0x41), 1)
  @test.assert_eq(utf8_byte_count(0x7F), 1)
  @test.assert_eq(utf8_byte_count(0x80), 2)
  @test.assert_eq(utf8_byte_count(0x7FF), 2)
  @test.assert_eq(utf8_byte_count(0x800), 3)
  @test.assert_eq(utf8_byte_count(0xFFFF), 3)
  @test.assert_eq(utf8_byte_count(0x1_0000), 4)
}

///|
// 这两条就是这次改动的本体：开关类告警不得带策略名前缀。
test "switch warnings are self-contained sentences without profile prefix" {
  assert_bytes(
    collect_status(1, security_warning_missing_lowercase),
    encode("生成关闭小写"),
  )
  assert_bytes(
    collect_status(1, security_warning_missing_uppercase),
    encode("生成关闭大写"),
  )
}

///|
test "policy-relative warnings keep the profile prefix" {
  assert_bytes(collect_status(1, security_warning_short), encode("标准 长度过短"))
  assert_bytes(collect_status(2, security_warning_short), encode("严格 长度过短"))
  assert_bytes(collect_status(0, security_warning_short), encode("兼容 长度过短"))
  assert_bytes(
    collect_status(1, security_warning_missing_digits), encode("标准 缺少数字"),
  )
  assert_bytes(
    collect_status(1, security_warning_missing_symbols), encode("标准 缺少符号"),
  )
  assert_bytes(collect_status(1, security_warning_invalid), encode("标准 配置无效"))
}

///|
test "no warning renders the policy label" {
  assert_bytes(collect_status(0, security_warning_none), encode("策略 兼容"))
  assert_bytes(collect_status(1, security_warning_none), encode("策略 标准"))
  assert_bytes(collect_status(2, security_warning_none), encode("策略 严格"))
}

///|
test "out-of-range profile and warning fall back safely" {
  // 未知策略回落"标准"，与 state.mbt 的 normalize 一致。
  assert_bytes(collect_status(9, security_warning_none), encode("策略 标准"))
  assert_bytes(collect_status(-1, security_warning_short), encode("标准 长度过短"))
  // 越界告警码不越界读表，按"无告警"处理。
  assert_bytes(collect_status(1, 99), encode("策略 标准"))
}

///|
test "every warning code has a non-empty message" {
  let mut code = security_warning_short
  while code <= security_warning_invalid {
    let bytes = collect_status(1, code)
    @test.assert_eq(bytes.length() > 0, true)
    code = code + 1
  }
}
