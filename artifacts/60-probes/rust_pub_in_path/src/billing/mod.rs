// billing is a SIBLING of orders, not inside it - so this call must be refused
// even though it is within the same crate (rules out "pub(crate)" being the
// mechanism doing the work here).
pub fn call_from_sibling_module() {
    crate::orders::internal::recompute_total();
}
