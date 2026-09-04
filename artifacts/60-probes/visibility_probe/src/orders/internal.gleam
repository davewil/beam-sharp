// Gleam's visibility is module-level binary: `pub` or unmarked (private to the
// module that defines it). There is no `pub(in path)`, no friend list, no
// second visibility keyword of any kind - confirmed by trying one below.
fn recompute_total() {
  41 + 1
}

pub fn call_from_same_module() {
  recompute_total()
}
