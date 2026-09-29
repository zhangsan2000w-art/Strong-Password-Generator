///|
pub let generate_ok : Int = 0

///|
pub let generate_invalid_config : Int = -1

///|
pub let generate_output_failed : Int = -2

///|
/// Backward-compatible adapter for the firmware package. The reusable
/// implementation lives in `securegen` and is also consumed by the CLI app.
pub fn generate_random_password(
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
  length : Int,
  digits : Bool,
  symbols : Bool,
) -> Int {
  if !random_policy_valid(length, true, true, digits, symbols) {
    return generate_invalid_config
  }
  @securegen.generate_password_compat(
    next_u32, emit, length, true, true, digits, symbols, false, false,
  )
}

///|
pub fn generate_random_password_with_policy(
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
  if !random_policy_valid(length, lowercase, uppercase, digits, symbols) {
    return generate_invalid_config
  }
  @securegen.generate_password_compat(
    next_u32, emit, length, lowercase, uppercase, digits, symbols, exclude_ambiguous,
    safe_symbols_only,
  )
}

///|
pub fn generate_pin(
  next_u32 : () -> UInt,
  emit : (Int) -> Bool,
  length : Int,
) -> Int {
  if length < pin_min_length || length > pin_max_length {
    return generate_invalid_config
  }
  @securegen.generate_pin_into(next_u32, emit, length)
}
