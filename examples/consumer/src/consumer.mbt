///|
/// Generate a standard credential through the public module API. A real
/// application must pass a cryptographically secure platform random source.
pub fn generate_standard(next_u32 : () -> UInt) -> Result[String, String] {
  let source = @securegen.RandomSource::new(next_u32)
  @securegen.generate_password_with_source(
    @securegen.PasswordPolicy::standard(),
    source,
  )
}

///|
/// Validate a credential at the consumer boundary without importing any
/// firmware or platform-adapter package.
pub fn accepts_standard(candidate : String) -> Bool {
  @securegen.validate_password(@securegen.PasswordPolicy::standard(), candidate)
}
