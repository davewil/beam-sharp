// 36c — the neighbour, MEASURED rather than cited (gleam 1.18.1, installed via
// mise, per the map's provenance rule).
//
// The question ticket 36 asks is whether a field assignment is checked at
// construction, at update, or at neither — and whether answering differently for
// the two is defensible. Gleam is the closest neighbour on this runtime, and it
// draws NO line between them:
//
//   error: Type mismatch  ┌─ src/gsurvey.gleam:9:13   Expected Int, Found Wrong
//   error: Type mismatch  ┌─ src/gsurvey.gleam:14:14  Expected Int, Found Wrong
//
// Two errors, one shape, one message. A language that had found an asymmetry
// here would show it here.

pub type Order {
  Order(id: Int, total: Int)
}

// Construction with a wrong-typed field value.
pub fn make(n: Int) -> Order {
  Order(id: Wrong, total: n)
}

// Gleam's record-update syntax, with a wrong-typed field value.
pub fn bump(o: Order) -> Order {
  Order(..o, total: Wrong)
}

pub type Wrong {
  Wrong
}
