pub mod internal;

// A sibling *inside* orders is allowed to call the pub(in crate::orders) function.
pub fn caller_inside_orders_is_allowed() {
    internal::recompute_total();
}
