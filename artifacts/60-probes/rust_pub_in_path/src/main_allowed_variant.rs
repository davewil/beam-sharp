mod orders;
mod billing;

fn main() {
    // Caller INSIDE crate::orders (a sibling file within the same subtree) -
    // allowed by pub(in crate::orders).
    orders::caller_inside_orders_is_allowed();
}
