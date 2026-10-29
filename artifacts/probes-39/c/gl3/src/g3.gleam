pub fn lit(n: Int) -> Int { n % 100 }
pub fn var(n: Int, d: Int) -> Int { n % d }
pub fn dv(n: Int, d: Int) -> Int { n / d }
pub fn bounded(n: Int) -> Int {
  case n >= 0 && n <= 99 {
    True -> n + 1
    False -> 0
  }
}
