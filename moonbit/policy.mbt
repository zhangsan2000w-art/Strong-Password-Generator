///|
pub let random_min_length : Int = 6

///|
pub let random_max_length : Int = 30

///|
pub let pin_min_length : Int = 4

///|
pub let pin_max_length : Int = 12

///|
pub let passphrase_min_words : Int = 3

///|
pub let passphrase_max_words : Int = 6

///|
pub let symbol_count : Int = 13

///|
pub let safe_symbol_count : Int = 9

///|
fn symbol_at(index : Int) -> Int {
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

///|
fn safe_symbol_at(index : Int) -> Int {
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
}

///|
pub fn is_ambiguous_character(ch : Int) -> Bool {
  ch == 48 || ch == 79 || ch == 49 || ch == 73 || ch == 108
}

///|
pub fn random_required_class_count(
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
) -> Int {
  (if lowercase { 1 } else { 0 }) +
  (if uppercase { 1 } else { 0 }) +
  (if digits { 1 } else { 0 }) +
  (if symbols { 1 } else { 0 })
}

///|
pub fn random_policy_valid(
  length : Int,
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
) -> Bool {
  let required = random_required_class_count(
    lowercase, uppercase, digits, symbols,
  )
  length >= random_min_length &&
  length <= random_max_length &&
  required > 0 &&
  length >= required
}

///|
fn random_pool_size(
  lowercase : Bool,
  uppercase : Bool,
  digits : Bool,
  symbols : Bool,
  exclude_ambiguous : Bool,
  safe_symbols_only : Bool,
) -> Int {
  (if lowercase { if exclude_ambiguous { 25 } else { 26 } } else { 0 }) +
  (if uppercase { if exclude_ambiguous { 24 } else { 26 } } else { 0 }) +
  (if digits { if exclude_ambiguous { 8 } else { 10 } } else { 0 }) +
  (if symbols { if safe_symbols_only { 9 } else { 13 } } else { 0 })
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
