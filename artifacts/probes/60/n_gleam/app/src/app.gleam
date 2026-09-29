// EXPECTED (before run): `lib.public_api` OK; importing lib/internal/secret from
// ANOTHER package is refused; @internal marked_internal is refused across packages;
// inside `lib` itself the sibling import of lib/internal/secret compiles.
import lib
import lib/internal/secret

pub fn main() -> Int {
  lib.public_api(1) + secret.helper(2) + lib.marked_internal(3)
}
