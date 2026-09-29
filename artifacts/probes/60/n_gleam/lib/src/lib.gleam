import lib/internal/secret

pub fn public_api(n: Int) -> Int {
  secret.helper(n) + 1
}

@internal
pub fn marked_internal(n: Int) -> Int {
  n
}
