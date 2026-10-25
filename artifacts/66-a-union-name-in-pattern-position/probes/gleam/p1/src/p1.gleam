pub type Shape {
  A(id: Int)
  B(id: Int)
  E(id: Int)
}

pub type Other {
  Named(id: Int)
  Mixed(id: String)
}

// (1) shared binding, same type: fine
pub fn ok(x: Shape) -> Int {
  case x {
    A(id: i) | B(id: i) -> i
    E(id: _) -> 0
  }
}

// (2) NEGATIVE control: the alternatives bind `i` at different types -> must be refused
pub fn bad_types(x: Other) -> Int {
  case x {
    Named(id: i) | Mixed(id: i) -> 1
  }
}

// (3) unreachable clause (exemplar 5's cousin): is it a warning or an error in Gleam?
pub fn unreachable(x: Shape) -> Int {
  case x {
    A(id: i) | B(id: i) -> i
    E(id: _) -> 0
    A(id: _) -> 99
  }
}

// (4) non-exhaustive: error
pub fn missing(x: Shape) -> Int {
  case x {
    A(id: i) | B(id: i) -> i
  }
}
