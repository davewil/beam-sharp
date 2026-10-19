pub type Shape { Circle(id: Int) Square(id: Int) Tri(id: Int) }
// alternative patterns bound to the WHOLE value with `as` (the closest Gleam has to `C c`)
pub fn ab(s: Shape) -> Int {
  case s {
    Circle(..) as c | Square(..) as c -> c.id
    Tri(..) -> 0
  }
}
// an unreachable clause: Square is covered by the wildcard above it
pub fn dead(s: Shape) -> Int {
  case s {
    _ -> 1
    Square(..) -> 2
  }
}
