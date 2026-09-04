# Rust `pub(in path)` probe

Two variants of the same crate, swapped in over `main.rs` / `billing/mod.rs` to isolate one
question each. The *_variant.rs files are the source actually used to produce each captured
output; the checked-in `main.rs`/`billing/mod.rs` are left in the BLOCKED state (variant 1) so
`cargo build` from a clean checkout reproduces `build_output_1_blocked_from_outside.txt` directly.

- Variant 1 (checked in as `main.rs` / `billing/mod.rs`) — RED control: a caller at the crate
  root AND a caller in a sibling module (`billing`, same crate, NOT under `orders`) both try to
  call `orders::internal::recompute_total()`, which is `pub(in crate::orders)`. Both calls are
  refused — output in `build_output_1_blocked_from_outside.txt`.
- Variant 2 (`main_allowed_variant.rs` / `billing/mod_allowed_variant.rs`) — GREEN: a caller
  *inside* `crate::orders` (a sibling file in the same subtree) calls the same function and it
  compiles and runs — output in `build_output_2_allowed_from_inside_path.txt` /
  `run_output_2.txt`.

To reproduce variant 2: `cp src/main_allowed_variant.rs src/main.rs && cp
src/billing/mod_allowed_variant.rs src/billing/mod.rs && cargo build && ./target/debug/pub_in_path_probe`
