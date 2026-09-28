///|
fn main {
  let mut state = 0x6d2b79f5U
  let next_u32 = fn() {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state
  }
  match
    @securegen.generate_password(
      @securegen.PasswordPolicy::standard(),
      next_u32,
    ) {
    Ok(value) => println(value)
    Err(message) => println("generation failed: \{message}")
  }
}
