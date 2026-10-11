import lib/internal/secret

pub fn public_api(n: Int) -> Int {
  secret.recompute_total(n) + 1
}

/// Marked with the attribute: hidden from docs and type-sensitive tooling.
@internal
pub fn attr_internal(n: Int) -> Int {
  n * 3
}

pub type Visible {
  Visible(Int)
}

@internal
pub type HiddenType {
  HiddenType(Int)
}
