fn reverse(xs: List(Int), acc: List(Int)) -> List(Int) {
  case xs {
    [] -> acc
    [x, ..rest] -> reverse(rest, [x, ..acc])
  }
}

fn series(n: Int, a: Int, b: Int, acc: List(Int)) -> List(Int) {
  case n <= 0 {
    True -> reverse(acc, [])
    False -> series(n - 1, b, a + b, [a, ..acc])
  }
}

pub fn fib(n: Int) -> List(Int) {
  case n <= 0 {
    True -> []
    False -> series(n, 0, 1, [])
  }
}
