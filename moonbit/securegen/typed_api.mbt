///|
/// A typed random-source boundary. The library deliberately does not choose a
/// platform RNG: native, browser, test, and embedded consumers inject one.
pub struct RandomSource {
  next : () -> UInt
}

///|
pub fn RandomSource::new(next : () -> UInt) -> RandomSource {
  { next, }
}

///|
pub fn RandomSource::next_u32(self : RandomSource) -> UInt {
  (self.next)()
}

///|
/// Separators supported by the portable passphrase generator.
pub enum PassphraseSeparator {
  Hyphen
  Period
  Underscore
} derive(Eq, Debug)

///|
pub fn PassphraseSeparator::hyphen() -> PassphraseSeparator {
  Hyphen
}

///|
pub fn PassphraseSeparator::period() -> PassphraseSeparator {
  Period
}

///|
pub fn PassphraseSeparator::underscore() -> PassphraseSeparator {
  Underscore
}

///|
fn PassphraseSeparator::index(self : PassphraseSeparator) -> Int {
  match self {
    Hyphen => 0
    Period => 1
    Underscore => 2
  }
}

///|
/// A portable passphrase policy. `complete_word=false` emits at most the first
/// four characters of each word, which is useful on constrained displays but
/// can reduce the number of unique outputs in a dictionary.
pub struct PassphrasePolicy {
  word_count : Int
  capitalize : Bool
  complete_word : Bool
  separator : PassphraseSeparator
}

///|
pub fn PassphrasePolicy::new(
  word_count : Int,
  capitalize? : Bool = false,
  complete_word? : Bool = true,
  separator? : PassphraseSeparator = Hyphen,
) -> PassphrasePolicy {
  { word_count, capitalize, complete_word, separator, }
}

///|
pub fn PassphrasePolicy::standard() -> PassphrasePolicy {
  PassphrasePolicy::new(4)
}

///|
pub fn PassphrasePolicy::word_count(self : PassphrasePolicy) -> Int {
  self.word_count
}

///|
pub fn PassphrasePolicy::is_valid(self : PassphrasePolicy) -> Bool {
  self.word_count >= 3 && self.word_count <= 12
}

///|
/// Generate a password using a typed random source.
pub fn generate_password_with_source(
  policy : PasswordPolicy,
  source : RandomSource,
) -> Result[String, String] {
  generate_password(policy, fn() { source.next_u32() })
}

///|
/// Generate a PIN using a typed random source.
pub fn generate_pin_with_source(
  length : Int,
  source : RandomSource,
) -> Result[String, String] {
  generate_pin(length, fn() { source.next_u32() })
}

///|
/// Generate a passphrase from an in-memory dictionary. Embedded consumers can
/// use `generate_passphrase_into` directly to read words from Flash.
pub fn generate_passphrase(
  policy : PassphrasePolicy,
  dictionary : Array[String],
  next_u32 : () -> UInt,
) -> Result[String, String] {
  if !policy.is_valid() || dictionary.length() == 0 {
    return Err("invalid passphrase policy or empty dictionary")
  }
  let builder = StringBuilder()
  let result = generate_passphrase_into(
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
    dictionary.length(),
    fn(index) { dictionary[index].length() },
    fn(index, offset) {
      match dictionary[index].get_char(offset) {
        Some(ch) => ch.to_int()
        None => -1
      }
    },
    policy.word_count,
    policy.capitalize,
    policy.complete_word,
    policy.separator.index(),
  )
  match result {
    0 => Ok(builder.to_string())
    -1 => Err("dictionary must contain non-empty lowercase ASCII words")
    _ => Err("output rejected generated passphrase character")
  }
}

///|
pub fn generate_passphrase_with_source(
  policy : PassphrasePolicy,
  dictionary : Array[String],
  source : RandomSource,
) -> Result[String, String] {
  generate_passphrase(policy, dictionary, fn() { source.next_u32() })
}

///|
/// Check that a candidate exactly satisfies the selected password policy.
pub fn validate_password(policy : PasswordPolicy, candidate : String) -> Bool {
  if !policy.is_valid() || candidate.length() != policy.length {
    return false
  }
  let mut has_lower = false
  let mut has_upper = false
  let mut has_digit = false
  let mut has_symbol = false
  for ch in candidate {
    let code = ch.to_int()
    if policy.exclude_ambiguous && is_ambiguous(code) {
      return false
    }
    if is_lower(code) {
      if !policy.lowercase {
        return false
      }
      has_lower = true
    } else if is_upper(code) {
      if !policy.uppercase {
        return false
      }
      has_upper = true
    } else if is_digit(code) {
      if !policy.digits {
        return false
      }
      has_digit = true
    } else if is_symbol(code) {
      if !policy.symbols || (policy.safe_symbols_only && !is_safe_symbol(code)) {
        return false
      }
      has_symbol = true
    } else {
      return false
    }
  }
  (!policy.lowercase || has_lower) &&
  (!policy.uppercase || has_upper) &&
  (!policy.digits || has_digit) &&
  (!policy.symbols || has_symbol)
}

///|
/// Check that a candidate is a decimal PIN in the supported 4..32 range.
pub fn validate_pin(candidate : String) -> Bool {
  if candidate.length() < 4 || candidate.length() > 32 {
    return false
  }
  for ch in candidate {
    if !is_digit(ch.to_int()) {
      return false
    }
  }
  true
}

///|
/// Password-strength bands based on an entropy estimate measured in tenths of
/// a bit. The thresholds are presentation aids, not an online-attack promise.
pub enum Strength {
  Unknown
  Weak
  Fair
  Strong
  VeryStrong
} derive(Eq, Debug)

///|
pub fn Strength::unknown() -> Strength {
  Unknown
}

///|
pub fn Strength::weak() -> Strength {
  Weak
}

///|
pub fn Strength::fair() -> Strength {
  Fair
}

///|
pub fn Strength::strong() -> Strength {
  Strong
}

///|
pub fn Strength::very_strong() -> Strength {
  VeryStrong
}

///|
pub fn strength_from_entropy_x10(entropy_x10 : Int) -> Strength {
  if entropy_x10 <= 0 {
    Unknown
  } else if entropy_x10 < 300 {
    Weak
  } else if entropy_x10 < 500 {
    Fair
  } else if entropy_x10 < 800 {
    Strong
  } else {
    VeryStrong
  }
}

///|
/// Estimate `log2(value)` in thousandths without floating-point arithmetic.
fn log2_milli(value : Int) -> Int {
  if value <= 1 {
    return 0
  }
  let mut integer = 0
  let mut base = 1
  while base * 2 <= value {
    base = base * 2
    integer = integer + 1
  }
  let mut normalized = value.to_uint64() * 65536UL / base.to_uint64()
  let mut fraction_1024 = 0
  let mut step = 0
  while step < 10 {
    normalized = normalized * normalized / 65536UL
    if normalized >= 131072UL {
      normalized = normalized / 2UL
      fraction_1024 = fraction_1024 + (1 << (9 - step))
    }
    step = step + 1
  }
  integer * 1000 + fraction_1024 * 1000 / 1024
}

///|
/// Estimate password entropy in tenths of a bit from length and pool size.
/// The value is a configuration estimate, not a claim about RNG quality.
pub fn PasswordPolicy::estimated_entropy_bits_x10(self : PasswordPolicy) -> Int {
  if !self.is_valid() {
    return 0
  }
  self.length *
  log2_milli(
    pool_size(
      self.lowercase,
      self.uppercase,
      self.digits,
      self.symbols,
      self.exclude_ambiguous,
      self.safe_symbols_only,
    ),
  ) /
  100
}

///|
/// Estimate decimal PIN entropy in tenths of a bit.
pub fn estimate_pin_entropy_bits_x10(length : Int) -> Int {
  if length < 4 || length > 32 {
    0
  } else {
    length * 3322 / 100
  }
}

///|
/// Estimate passphrase entropy in tenths of a bit. `unique_output_count` must
/// be the number of distinct emitted words or prefixes after transformations.
pub fn estimate_passphrase_entropy_bits_x10(
  policy : PassphrasePolicy,
  unique_output_count : Int,
) -> Int {
  if !policy.is_valid() || unique_output_count <= 1 {
    0
  } else {
    policy.word_count * log2_milli(unique_output_count) / 100
  }
}
