// Visible only to code inside the `crate::orders` subtree - the scope is a
// MODULE PATH, not a whole-crate `pub(crate)` and not a named-friend list.
pub(in crate::orders) fn recompute_total() {
    println!("recomputed");
}
