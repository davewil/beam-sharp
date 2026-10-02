import lib/internal/secret

pub fn total(x: Int) -> Int {
  secret.recompute(x) + helper(x)
}

@internal
pub fn helper(x: Int) -> Int {
  x
}
