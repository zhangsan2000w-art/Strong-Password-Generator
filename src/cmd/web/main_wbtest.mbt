///|
test "web password profiles remain library policies" {
  let compatible = password_policy("compatible", 24)
  let standard = password_policy("standard", 16)
  let strict = password_policy("strict", 32)
  @test.assert_eq(compatible.length(), 24)
  @test.assert_eq(standard.is_valid(), true)
  @test.assert_eq(strict.length(), 32)
}

///|
test "web input and entropy labels are deterministic helpers" {
  @test.assert_eq(parse_positive_int("16"), Some(16))
  @test.assert_eq(parse_positive_int("0"), None)
  @test.assert_eq(parse_positive_int("1x"), None)
  @test.assert_eq(strength_label(799), "Strong")
  @test.assert_eq(strength_label(800), "Very strong")
}
