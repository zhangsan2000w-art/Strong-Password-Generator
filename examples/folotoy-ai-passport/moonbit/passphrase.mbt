///|
/// Backward-compatible adapter for the AI Passport Flash dictionary. The
/// reusable implementation accepts any callback-backed dictionary.
pub fn generate_passphrase(
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
  @securegen.generate_passphrase_into(
    next_u32, emit, dictionary_count, dictionary_length, dictionary_char, word_count,
    capitalize, complete_word, separator_index,
  )
}
