///|
struct Sequence {
  values : Array[UInt]
  mut index : Int
}

///|
fn Sequence::new(values : Array[UInt]) -> Sequence {
  { values, index: 0, }
}

///|
fn Sequence::next(self : Sequence) -> UInt {
  let value = self.values[self.index % self.values.length()]
  self.index = self.index + 1
  value
}

///|
test "standard policy produces a reusable String result" {
  let source = Sequence::new([1U, 9U, 17U, 25U, 33U, 41U, 49U, 57U])
  match generate_password(PasswordPolicy::standard(), fn() { source.next() }) {
    Ok(value) => @test.assert_eq(value.length(), 16)
    Err(message) => @test.fail(message)
  }
}

///|
test "policy length can be overridden" {
  let source = Sequence::new([1U, 9U, 17U, 25U, 33U, 41U, 49U, 57U])
  let policy = PasswordPolicy::compatible().with_length(24)
  @test.assert_eq(policy.length(), 24)
  match generate_password(policy, fn() { source.next() }) {
    Ok(value) => @test.assert_eq(value.length(), 24)
    Err(message) => @test.fail(message)
  }
}

///|
test "standard policy guarantees every enabled character class" {
  let source = Sequence::new([1U, 9U, 17U, 25U, 33U, 41U, 49U, 57U])
  match generate_password(PasswordPolicy::standard(), fn() { source.next() }) {
    Ok(value) => {
      let mut lower = false
      let mut upper = false
      let mut digit = false
      let mut symbol = false
      for ch in value {
        let code = ch.to_int()
        if code >= 97 && code <= 122 {
          lower = true
        }
        if code >= 65 && code <= 90 {
          upper = true
        }
        if code >= 48 && code <= 57 {
          digit = true
        }
        if !(code >= 97 && code <= 122) &&
          !(code >= 65 && code <= 90) &&
          !(code >= 48 && code <= 57) {
          symbol = true
        }
        @test.assert_eq(
          code == 48 || code == 79 || code == 49 || code == 73 || code == 108,
          false,
        )
      }
      @test.assert_eq(lower && upper && digit && symbol, true)
    }
    Err(message) => @test.fail(message)
  }
}

///|
test "typed API rejects an invalid policy" {
  let policy = PasswordPolicy::new(
    3,
    lowercase=true,
    uppercase=true,
    digits=true,
    symbols=true,
  )
  @test.assert_eq(policy.is_valid(), false)
  match generate_password(policy, fn() { 1U }) {
    Ok(_) => @test.fail("invalid policy unexpectedly generated output")
    Err(message) => @test.assert_eq(message, "invalid password policy")
  }
}

///|
test "PIN API returns a String for application consumers" {
  let source = Sequence::new([0U, 1U, 2U, 3U, 4U, 5U])
  match generate_pin(6, fn() { source.next() }) {
    Ok(value) => @test.assert_eq(value, "012345")
    Err(message) => @test.fail(message)
  }
}

///|
test "allocation-controlled API reports a rejected sink" {
  @test.assert_eq(
    generate_password_into(PasswordPolicy::standard(), fn() { 7U }, fn(_) {
      false
    }),
    -2,
  )
}

///|
test "unbiased index redraws samples from the incomplete bucket" {
  let source = Sequence::new([0xffffffffU, 7U])
  @test.assert_eq(unbiased_index(fn() { source.next() }, 10), 7)
  @test.assert_eq(unbiased_index(fn() { source.next() }, 1), 0)
  @test.assert_eq(unbiased_index(fn() { source.next() }, 0), -1)
}

///|
test "callback dictionary keeps passphrases independent of storage" {
  let words = ["apple", "baker"]
  let builder = StringBuilder()
  let source = Sequence::new([0U])
  let result = generate_passphrase_into(
    fn() { source.next() },
    fn(code) {
      builder.write_char(code.to_char().unwrap())
      true
    },
    words.length(),
    fn(index) { words[index].length() },
    fn(index, offset) { words[index].get_char(offset).unwrap().to_int() },
    3,
    false,
    true,
    0,
  )
  @test.assert_eq(result, 0)
  @test.assert_eq(builder.to_string(), "apple-apple-apple")
}

///|
test "typed random source supports password PIN and passphrase APIs" {
  let source = Sequence::new([0U, 1U, 2U, 3U, 4U, 5U, 6U, 7U])
  let random = RandomSource::new(fn() { source.next() })
  match generate_password_with_source(PasswordPolicy::standard(), random) {
    Ok(value) =>
      @test.assert_eq(
        validate_password(PasswordPolicy::standard(), value),
        true,
      )
    Err(message) => @test.fail(message)
  }
  match generate_pin_with_source(8, random) {
    Ok(value) => @test.assert_eq(validate_pin(value), true)
    Err(message) => @test.fail(message)
  }
  match
    generate_passphrase_with_source(
      PassphrasePolicy::new(
        3,
        capitalize=true,
        separator=PassphraseSeparator::underscore(),
      ),
      ["apple", "baker"],
      random,
    ) {
    Ok(value) => @test.assert_eq(value, "Baker_Apple_Baker")
    Err(message) => @test.fail(message)
  }
}

///|
test "public validators reject policy violations" {
  let compatible = PasswordPolicy::compatible()
  @test.assert_eq(validate_password(compatible, "Abcdefgh2345"), true)
  @test.assert_eq(validate_password(compatible, "Abcdefgh23!5"), false)
  @test.assert_eq(validate_pin("01234567890123456789012345678901"), true)
  @test.assert_eq(validate_pin("123x"), false)
}

///|
test "entropy estimates and strength bands are portable" {
  let entropy = PasswordPolicy::standard().estimated_entropy_bits_x10()
  @test.assert_eq(entropy > 800, true)
  @test.assert_eq(strength_from_entropy_x10(entropy), Strength::very_strong())
  @test.assert_eq(estimate_pin_entropy_bits_x10(6), 199)
  @test.assert_eq(
    estimate_passphrase_entropy_bits_x10(PassphrasePolicy::standard(), 2048),
    440,
  )
}

///|
test "library bounds match CLI contract" {
  @test.assert_eq(PasswordPolicy::new(4, symbols=false).is_valid(), true)
  @test.assert_eq(PasswordPolicy::new(128).is_valid(), true)
  @test.assert_eq(PasswordPolicy::new(129).is_valid(), false)
  match generate_pin(32, fn() { 0U }) {
    Ok(value) => @test.assert_eq(value.length(), 32)
    Err(message) => @test.fail(message)
  }
}
