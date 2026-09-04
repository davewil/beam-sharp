mod orders;
mod billing;

fn main() {
    // Caller from crate root (outside orders/billing entirely) tries to reach
    // a function that orders::internal has restricted to `pub(in crate::orders)`.
    orders::internal::recompute_total();
}
