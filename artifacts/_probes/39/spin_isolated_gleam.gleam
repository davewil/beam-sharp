// Only run is public, matching beam-sharp's Day01Isolated (see the comment
// in spin_isolated.erl for why export visibility matters to this
// measurement).
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

pub fn run(left: Int) -> #(Int, Int) {
  spin(50, 1, left, 0)
}
