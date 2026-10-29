import lib
import lib/internal/helper
import lib/open/api

pub fn main() {
  lib.total(1) + helper.recompute(2) + api.secret(3)
}
