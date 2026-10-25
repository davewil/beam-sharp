pub type Shape {
  A(id: Int)
  B(id: Int)
  E(id: Int, name: String)
}

// whole-value binder over alternative patterns: what is `c`'s type? (answer: Shape, not "A | B")
pub fn whole(x: Shape) -> Int {
  case x {
    A(..) as c | B(..) as c -> take_ab(c)
    E(..) -> 0
  }
}

// a function that wants ONLY A or B has no type to name: there is no sub-union of a custom type.
fn take_ab(c: Shape) -> Int {
  case c {
    A(id: i) | B(id: i) -> i
    E(..) -> -1
  }
}
