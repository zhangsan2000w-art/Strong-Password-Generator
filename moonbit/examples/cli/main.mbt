///|
struct CliOptions {
  profile : String
  length : Int
  count : Int
  pin_digits : Int
  help : Bool
}

///|
fn default_options() -> CliOptions {
  { profile: "standard", length: 0, count: 1, pin_digits: 0, help: false, }
}

///|
fn parse_positive_int(text : String) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  let mut index = 0
  while index < text.length() {
    let code = match text.get_char(index) {
      Some(character) => character.to_int()
      None => return None
    }
    if code < 48 || code > 57 || value > 100000 {
      return None
    }
    value = value * 10 + code - 48
    index = index + 1
  }
  if value > 0 {
    Some(value)
  } else {
    None
  }
}

///|
fn option_value(
  args : Array[String],
  index : Int,
  name : String,
) -> Result[String, String] {
  if index + 1 >= args.length() {
    Err("missing value after \{name}")
  } else {
    Ok(args[index + 1])
  }
}

///|
fn parse_args(args : Array[String]) -> Result[CliOptions, String] {
  let defaults = default_options()
  let mut profile = defaults.profile
  let mut length = defaults.length
  let mut count = defaults.count
  let mut pin_digits = defaults.pin_digits
  let mut help = defaults.help
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    if argument == "--help" || argument == "-h" {
      help = true
      index = index + 1
    } else if argument == "--profile" {
      let value = match option_value(args, index, argument) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if value != "compatible" && value != "standard" && value != "strict" {
        return Err("profile must be compatible, standard, or strict")
      }
      profile = value
      index = index + 2
    } else if argument == "--length" ||
      argument == "--count" ||
      argument == "--pin" {
      let value_text = match option_value(args, index, argument) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let value = match parse_positive_int(value_text) {
        Some(value) => value
        None => return Err("\{argument} requires a positive integer")
      }
      if argument == "--length" {
        if value < 4 || value > 128 {
          return Err("--length must be between 4 and 128")
        }
        length = value
      } else if argument == "--count" {
        if value > 100 {
          return Err("--count must be between 1 and 100")
        }
        count = value
      } else {
        if value < 4 || value > 32 {
          return Err("--pin must be between 4 and 32 digits")
        }
        pin_digits = value
      }
      index = index + 2
    } else {
      return Err("unknown option: \{argument}")
    }
  }
  Ok({ profile, length, count, pin_digits, help, })
}

///|
fn policy_for(options : CliOptions) -> @securegen.PasswordPolicy {
  let policy = if options.profile == "compatible" {
    @securegen.PasswordPolicy::compatible()
  } else if options.profile == "strict" {
    @securegen.PasswordPolicy::strict()
  } else {
    @securegen.PasswordPolicy::standard()
  }
  if options.length > 0 {
    policy.with_length(options.length)
  } else {
    policy
  }
}

///|
fn secure_random_u32() -> UInt {
  let bytes = match @env.rand(4) {
    Some(bytes) => bytes
    None =>
      abort(
        "the platform did not provide a cryptographically secure random source",
      )
  }
  bytes[0].to_uint() |
  (bytes[1].to_uint() << 8) |
  (bytes[2].to_uint() << 16) |
  (bytes[3].to_uint() << 24)
}

///|
fn print_help() -> Unit {
  println("SecureGen CLI - generate credentials using operating-system entropy")
  println("")
  println(
    "Usage: moon -C moonbit run examples/cli --target js --release -- [options]",
  )
  println("")
  println(
    "  --profile compatible|standard|strict  Password policy (default: standard)",
  )
  println("  --length N                            Password length, 4..128")
  println(
    "  --pin N                               Generate an N-digit PIN instead",
  )
  println("  --count N                             Generate 1..100 values")
  println("  -h, --help                            Show this help")
  println("")
  println(
    "Secrets are printed to standard output. Avoid shell history and shared logs.",
  )
}

///|
fn application_args() -> Array[String] {
  let raw = @env.args()
  if raw.length() > 2 {
    raw[2:].to_owned()
  } else {
    []
  }
}

///|
fn main {
  let options = match parse_args(application_args()) {
    Ok(options) => options
    Err(message) => {
      println("error: \{message}")
      println("use --help for usage")
      return
    }
  }
  if options.help {
    print_help()
    return
  }
  let policy = policy_for(options)
  let mut generated = 0
  while generated < options.count {
    let result = if options.pin_digits > 0 {
      @securegen.generate_pin(options.pin_digits, secure_random_u32)
    } else {
      @securegen.generate_password(policy, secure_random_u32)
    }
    match result {
      Ok(value) => println(value)
      Err(message) => {
        println("generation failed: \{message}")
        return
      }
    }
    generated = generated + 1
  }
}
