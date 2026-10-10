import lib/internal/helper

pub fn total(n: Int) -> Int {
  helper.recompute(n)
}

@internal
pub fn also_hidden(n: Int) -> Int {
  n
}
