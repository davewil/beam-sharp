fn wrap(n: Int) -> Int {
  { { n % 100 } + 100 } % 100
}

fn hit(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> 0
  }
}

fn spin(pos: Int, step: Int, left: Int, zeros: Int) -> #(Int, Int) {
  case left {
    0 -> #(pos, zeros)
    _ -> {
      let next = wrap(pos + step)
      spin(next, step, left - 1, zeros + hit(next))
    }
  }
}

fn sign(d: Int) -> Int {
  case d < 0 {
    True -> -1
    False -> 1
  }
}

fn size_(d: Int) -> Int {
  case d < 0 {
    True -> -d
    False -> d
  }
}

fn clicks(rs: List(Int), pos: Int, zeros: Int) -> Int {
  case rs {
    [] -> zeros
    [d, ..rest] -> {
      let #(next, hits) = spin(pos, sign(d), size_(d), zeros)
      clicks(rest, next, hits)
    }
  }
}

pub fn part_two(rs: List(Int)) -> Int {
  clicks(rs, 50, 0)
}
