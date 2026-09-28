///|
/// A portable password policy. The policy has no dependency on ESP-IDF,
/// FoloToy, LVGL, a filesystem, or a particular random-number provider.
pub struct PasswordPolicy {
  length : Int
  lowercase : Bool
  uppercase : Bool
  digits : Bool
  symbols : Bool
  exclude_ambiguous : Bool
  safe_symbols_only : Bool
}

///|
/// Construct a password policy for a library, command-line, web, or embedded
/// consumer. Use `PasswordPolicy::is_valid` before presenting custom values.
pub fn PasswordPolicy::new(
  length : Int,
  lowercase? : Bool = true,
  uppercase? : Bool = true,
  digits? : Bool = true,
  symbols? : Bool = true,
  exclude_ambiguous? : Bool = true,
  safe_symbols_only? : Bool = true,
) -> PasswordPolicy {
  {
    length,
    lowercase,
    uppercase,
    digits,
    symbols,
    exclude_ambiguous,
    safe_symbols_only,
  }
}

///|
/// A broadly compatible policy for sites that reject punctuation.
pub fn PasswordPolicy::compatible() -> PasswordPolicy {
  PasswordPolicy::new(12, symbols=false)
}

///|
/// The recommended default for general-purpose credentials.
pub fn PasswordPolicy::standard() -> PasswordPolicy {
  PasswordPolicy::new(16)
}

///|
/// A longer policy that keeps the complete supported character set.
pub fn PasswordPolicy::strict() -> PasswordPolicy {
  PasswordPolicy::new(20, exclude_ambiguous=false, safe_symbols_only=false)
}

///|
pub fn PasswordPolicy::length(self : PasswordPolicy) -> Int {
  self.length
}

///|
/// Return the same policy with a different output length. This preserves the
/// selected profile's character-set rules.
pub fn PasswordPolicy::with_length(
  self : PasswordPolicy,
  length : Int,
) -> PasswordPolicy {
  { ..self, length, }
}

///|
pub fn PasswordPolicy::is_valid(self : PasswordPolicy) -> Bool {
  policy_valid(
    self.length,
    self.lowercase,
    self.uppercase,
    self.digits,
    self.symbols,
  )
}

///|
/// Generate a password as a MoonBit `String`. Randomness is injected so a
/// native application, browser, test, or microcontroller can provide the
/// entropy source appropriate to its platform.
pub fn generate_password(
  policy : PasswordPolicy,
  next_u32 : () -> UInt,
) -> Result[String, String] {
  let builder = StringBuilder()
  let result = generate_password_into(policy, next_u32, fn(code) {
    match code.to_char() {
      Some(ch) => {
        builder.write_char(ch)
        true
      }
      None => false
    }
  })
  match result {
    0 => Ok(builder.to_string())
    -1 => Err("invalid password policy")
    _ => Err("output rejected generated character")
  }
}

///|
/// Generate a password into a caller-owned sink. This allocation-controlled
/// API is the integration point used by embedded firmware.
pub fn generate_password_into(
  policy : PasswordPolicy,
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
) -> Int {
  generate_password_compat(
    next_u32,
    emit,
    policy.length,
    policy.lowercase,
    policy.uppercase,
    policy.digits,
    policy.symbols,
    policy.exclude_ambiguous,
    policy.safe_symbols_only,
  )
}

///|
/// Compatibility API for C and existing callback-based consumers. New
/// MoonBit applications should prefer `PasswordPolicy` and
/// `generate_password` or `generate_password_into`.
pub fn generate_password_compat(
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
  length : Int,
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
  exclude_ambiguous : Bool,
  safe_symbols_only : Bool,
) -> Int {
  if !policy_valid(length, lowercase, uppercase, digits, symbols) {
    return -1
  }
  let output = FixedArray::make(length, 0)
  let mut cursor = 0
  if lowercase {
    output[cursor] = lowercase_at(
      unbiased_index(next_u32, lowercase_count(exclude_ambiguous)),
      exclude_ambiguous,
    )
    cursor = cursor + 1
  }
  if uppercase {
    output[cursor] = uppercase_at(
      unbiased_index(next_u32, uppercase_count(exclude_ambiguous)),
      exclude_ambiguous,
    )
    cursor = cursor + 1
  }
  if digits {
    output[cursor] = digit_at(
      unbiased_index(next_u32, digit_count(exclude_ambiguous)),
      exclude_ambiguous,
    )
    cursor = cursor + 1
  }
  if symbols {
    output[cursor] = symbol_at(
      unbiased_index(next_u32, symbol_count(safe_symbols_only)),
      safe_symbols_only,
    )
    cursor = cursor + 1
  }
  let pool_size = pool_size(
    lowercase, uppercase, digits, symbols, exclude_ambiguous, safe_symbols_only,
  )
  while cursor < length {
    output[cursor] = pool_at(
      unbiased_index(next_u32, pool_size),
      lowercase,
      uppercase,
      digits,
      symbols,
      exclude_ambiguous,
      safe_symbols_only,
    )
    cursor = cursor + 1
  }
  let mut index = length - 1
  while index > 0 {
    let other = unbiased_index(next_u32, index + 1)
    let temporary = output[index]
    output[index] = output[other]
    output[other] = temporary
    index = index - 1
  }
  if !candidate_valid(
      output, lowercase, uppercase, digits, symbols, exclude_ambiguous, safe_symbols_only,
    ) {
    return -1
  }
  index = 0
  while index < length {
    if !emit(output[index]) {
      return -2
    }
    index = index + 1
  }
  0
}

///|
/// Generate a decimal PIN into a caller-owned sink.
pub fn generate_pin_into(
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
  length : Int,
) -> Int {
  if length < 4 || length > 12 {
    return -1
  }
  let mut index = 0
  while index < length {
    if !emit(48 + unbiased_index(next_u32, 10)) {
      return -2
    }
    index = index + 1
  }
  0
}

///|
/// Generate a decimal PIN as a MoonBit `String`.
pub fn generate_pin(
  length : Int,
  next_u32 : () -> UInt,
) -> Result[String, String] {
  let builder = StringBuilder()
  let result = generate_pin_into(
    next_u32,
    fn(code) {
      match code.to_char() {
        Some(ch) => {
          builder.write_char(ch)
          true
        }
        None => false
      }
    },
    length,
  )
  match result {
    0 => Ok(builder.to_string())
    -1 => Err("PIN length must be between 4 and 12")
    _ => Err("output rejected generated digit")
  }
}

///|
/// Generate a passphrase into a caller-owned sink. Dictionary access remains
/// callback-based so callers can use arrays, memory-mapped data, or Flash.
pub fn generate_passphrase_into(
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
  dictionary_count : Int,
  dictionary_length : (Int) -> Int,
  dictionary_char : (Int, Int) -> Int,
  word_count : Int,
  capitalize : Bool,
  complete_word : Bool,
  separator_index : Int,
) -> Int {
  let separator = separator_at(separator_index)
  if word_count < 3 || word_count > 6 || dictionary_count <= 0 || separator < 0 {
    return -1
  }
  let mut word_number = 0
  while word_number < word_count {
    let word_index = unbiased_index(next_u32, dictionary_count)
    let source_length = dictionary_length(word_index)
    if source_length <= 0 {
      return -1
    }
    let output_length = if complete_word || source_length <= 4 {
      source_length
    } else {
      4
    }
    let mut character_index = 0
    while character_index < output_length {
      let mut ch = dictionary_char(word_index, character_index)
      if !is_lower(ch) {
        return -1
      }
      if capitalize && character_index == 0 {
        ch = ch - 32
      }
      if !emit(ch) {
        return -2
      }
      character_index = character_index + 1
    }
    if word_number + 1 < word_count && !emit(separator) {
      return -2
    }
    word_number = word_number + 1
  }
  0
}

///|
/// Map a uniform 32-bit sample to `[0, bound)` without modulo bias.
pub fn unbiased_index(next_u32 : () -> UInt, bound : Int) -> Int {
  if bound <= 0 {
    return -1
  }
  if bound == 1 {
    return 0
  }
  let divisor = bound.reinterpret_as_uint()
  let limit = 0xffffffffU - 0xffffffffU % divisor
  let mut sample = next_u32()
  while sample >= limit {
    sample = next_u32()
  }
  (sample % divisor).reinterpret_as_int()
}

///|
fn policy_valid(
  length : Int,
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
) -> Bool {
  let required = (if lowercase { 1 } else { 0 }) +
    (if uppercase { 1 } else { 0 }) +
    (if digits { 1 } else { 0 }) +
    (if symbols { 1 } else { 0 })
  length >= 6 && length <= 30 && required > 0 && length >= required
}

///|
fn is_lower(ch : Int) -> Bool {
  ch >= 97 && ch <= 122
}

///|
fn is_upper(ch : Int) -> Bool {
  ch >= 65 && ch <= 90
}

///|
fn is_digit(ch : Int) -> Bool {
  ch >= 48 && ch <= 57
}

///|
fn is_ambiguous(ch : Int) -> Bool {
  ch == 48 || ch == 79 || ch == 49 || ch == 73 || ch == 108
}

///|
fn is_symbol(ch : Int) -> Bool {
  ch == 33 ||
  ch == 64 ||
  ch == 35 ||
  ch == 36 ||
  ch == 37 ||
  ch == 94 ||
  ch == 38 ||
  ch == 42 ||
  ch == 95 ||
  ch == 45 ||
  ch == 43 ||
  ch == 61 ||
  ch == 63
}

///|
fn is_safe_symbol(ch : Int) -> Bool {
  ch == 33 ||
  ch == 64 ||
  ch == 35 ||
  ch == 36 ||
  ch == 37 ||
  ch == 42 ||
  ch == 95 ||
  ch == 45 ||
  ch == 63
}

///|
fn lowercase_count(exclude_ambiguous : Bool) -> Int {
  if exclude_ambiguous {
    25
  } else {
    26
  }
}

///|
fn uppercase_count(exclude_ambiguous : Bool) -> Int {
  if exclude_ambiguous {
    24
  } else {
    26
  }
}

///|
fn digit_count(exclude_ambiguous : Bool) -> Int {
  if exclude_ambiguous {
    8
  } else {
    10
  }
}

///|
fn lowercase_at(index : Int, exclude_ambiguous : Bool) -> Int {
  if exclude_ambiguous && index >= 11 {
    98 + index
  } else {
    97 + index
  }
}

///|
fn uppercase_at(index : Int, exclude_ambiguous : Bool) -> Int {
  if !exclude_ambiguous {
    return 65 + index
  }
  if index < 8 {
    65 + index
  } else if index < 13 {
    66 + index
  } else {
    67 + index
  }
}

///|
fn digit_at(index : Int, exclude_ambiguous : Bool) -> Int {
  if exclude_ambiguous {
    50 + index
  } else {
    48 + index
  }
}

///|
fn symbol_count(safe_only : Bool) -> Int {
  if safe_only {
    9
  } else {
    13
  }
}

///|
fn symbol_at(index : Int, safe_only : Bool) -> Int {
  if safe_only {
    match index {
      0 => 33
      1 => 64
      2 => 35
      3 => 36
      4 => 37
      5 => 42
      6 => 95
      7 => 45
      8 => 63
      _ => -1
    }
  } else {
    match index {
      0 => 33
      1 => 64
      2 => 35
      3 => 36
      4 => 37
      5 => 94
      6 => 38
      7 => 42
      8 => 95
      9 => 45
      10 => 43
      11 => 61
      12 => 63
      _ => -1
    }
  }
}

///|
fn pool_size(
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
  exclude_ambiguous : Bool,
  safe_symbols_only : Bool,
) -> Int {
  (if lowercase { lowercase_count(exclude_ambiguous) } else { 0 }) +
  (if uppercase { uppercase_count(exclude_ambiguous) } else { 0 }) +
  (if digits { digit_count(exclude_ambiguous) } else { 0 }) +
  (if symbols { symbol_count(safe_symbols_only) } else { 0 })
}

///|
fn pool_at(
  original_index : Int,
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  _symbols : Bool,
  exclude_ambiguous : Bool,
  safe_symbols_only : Bool,
) -> Int {
  let mut index = original_index
  if lowercase {
    let count = lowercase_count(exclude_ambiguous)
    if index < count {
      return lowercase_at(index, exclude_ambiguous)
    }
    index = index - count
  }
  if uppercase {
    let count = uppercase_count(exclude_ambiguous)
    if index < count {
      return uppercase_at(index, exclude_ambiguous)
    }
    index = index - count
  }
  if digits {
    let count = digit_count(exclude_ambiguous)
    if index < count {
      return digit_at(index, exclude_ambiguous)
    }
    index = index - count
  }
  symbol_at(index, safe_symbols_only)
}

///|
fn candidate_valid(
  output : FixedArray[Int],
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
  exclude_ambiguous : Bool,
  safe_symbols_only : Bool,
) -> Bool {
  let mut has_lower = false
  let mut has_upper = false
  let mut has_digit = false
  let mut has_symbol = false
  for ch in output {
    if exclude_ambiguous && is_ambiguous(ch) {
      return false
    }
    if is_lower(ch) {
      if !lowercase {
        return false
      }
      has_lower = true
    } else if is_upper(ch) {
      if !uppercase {
        return false
      }
      has_upper = true
    } else if is_digit(ch) {
      if !digits {
        return false
      }
      has_digit = true
    } else if is_symbol(ch) {
      if !symbols || (safe_symbols_only && !is_safe_symbol(ch)) {
        return false
      }
      has_symbol = true
    } else {
      return false
    }
  }
  (!lowercase || has_lower) &&
  (!uppercase || has_upper) &&
  (!digits || has_digit) &&
  (!symbols || has_symbol)
}

///|
fn separator_at(index : Int) -> Int {
  match index {
    0 => 45
    1 => 46
    2 => 95
    _ => -1
  }
}
