// Probe for ticket 39 sub-decision 1: verbatim copy of the wrap/hit/spin
// functions from aoc/bench/gleam/src/bench_gleam.gleam, plus a spin_only
// entry point.
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

pub fn spin_only(step: Int, left: Int) -> #(Int, Int) {
  spin(50, step, left, 0)
}
