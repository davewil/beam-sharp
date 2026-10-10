import lib
import lib/internal/helper

pub fn main() {
  let _ = lib.total(1)
  let _ = lib.also_hidden(1)
  helper.recompute(1)
}
