///|
test "CLI defaults to one standard password" {
  match parse_args([]) {
    Ok(options) => {
      @test.assert_eq(options.profile, "standard")
      @test.assert_eq(options.count, 1)
      @test.assert_eq(options.pin_digits, 0)
      @test.assert_eq(policy_for(options).length(), 16)
    }
    Err(message) => @test.fail(message)
  }
}

///|
test "CLI parses profile length count and PIN" {
  match
    parse_args([
      "--profile", "strict", "--length", "32", "--count", "3", "--pin", "8",
    ]) {
    Ok(options) => {
      @test.assert_eq(options.profile, "strict")
      @test.assert_eq(policy_for(options).length(), 32)
      @test.assert_eq(options.count, 3)
      @test.assert_eq(options.pin_digits, 8)
    }
    Err(message) => @test.fail(message)
  }
}

///|
test "CLI rejects unsupported values" {
  @test.assert_eq(parse_args(["--profile", "unsafe"]) is Err(_), true)
  @test.assert_eq(parse_args(["--length", "3"]) is Err(_), true)
  @test.assert_eq(parse_args(["--count", "101"]) is Err(_), true)
  @test.assert_eq(parse_args(["--pin", "letters"]) is Err(_), true)
  @test.assert_eq(parse_args(["--unknown"]) is Err(_), true)
}
