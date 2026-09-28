///|
struct Sequence {
  values : Array[UInt]
  mut index : Int
}

///|
fn Sequence::next(self : Sequence) -> UInt {
  let value = self.values[self.index % self.values.length()]
  self.index = self.index + 1
  value
}

///|
test "independent module generates and validates through public API" {
  let sequence : Sequence = {
    values: [0U, 3U, 9U, 17U, 25U, 41U, 57U, 73U],
    index: 0,
  }
  match generate_standard(fn() { sequence.next() }) {
    Ok(value) => {
      @test.assert_eq(value.length(), 16)
      @test.assert_eq(accepts_standard(value), true)
    }
    Err(message) => @test.fail(message)
  }
}

///|
test "consumer does not weaken validation rules" {
  @test.assert_eq(accepts_standard("abcdefgh2345!xyz"), false)
}
