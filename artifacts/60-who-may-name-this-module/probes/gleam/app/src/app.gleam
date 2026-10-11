import lib
import lib/internal/secret

pub fn main() -> Int {
  secret.recompute_total(5) + lib.attr_internal(2)
}
