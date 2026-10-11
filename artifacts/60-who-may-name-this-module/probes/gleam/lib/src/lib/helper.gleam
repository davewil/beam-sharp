import lib/internal/secret

// same package, different directory: may import the internal module
pub fn via_helper(n: Int) -> Int {
  secret.recompute_total(n)
}

fn really_private(n: Int) -> Int {
  n
}
