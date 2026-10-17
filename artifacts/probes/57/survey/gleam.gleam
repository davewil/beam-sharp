pub fn pat(x: Int) -> String {
  case x {
    -5 -> "neg5"
    n if n >= -5 -> "ge"
    _ -> "other"
  }
}
pub fn expr() -> Int { -5 }
pub fn two() -> Int { --5 }
