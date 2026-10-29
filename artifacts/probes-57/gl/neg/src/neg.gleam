pub fn g(n: Int) -> String {
  case n {
    n if n >= -5 && n <= 5 -> "in"
    _ -> "out"
  }
}
pub fn h(n: Int) -> String {
  case n {
    n if n >= 2 - 7 -> "ok"
    _ -> "no"
  }
}
pub fn p(n: Int) -> String {
  case n {
    -5 -> "m5"
    _ -> "o"
  }
}
pub fn x(n: Int) -> Int {
  let y = -n
  y
}
