pub fn classify(x: Float) -> String {
  case x {
    _ if x >=. -5.0 -> "hi"
    _ -> "lo"
  }
}

pub fn sign(n: Int) -> String {
  case n {
    -1 -> "neg_one"
    0 -> "zero"
    _ -> "other"
  }
}

pub fn main() {
  classify(-5.0)
  classify(-6.0)
  sign(-1)
}
