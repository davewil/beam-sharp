mod acme {
    pub mod orders {
        // private module: nameable by `orders` itself and its descendants only
        mod rules {
            pub fn recompute(xs: &[i32]) -> i32 { xs.iter().sum() }
            // a per-FUNCTION subtree marker: nameable only inside acme::orders
            pub(in crate::acme::orders) fn tagged() -> i32 { 7 }
        }
        pub fn total(xs: &[i32]) -> i32 { rules::recompute(xs) + rules::tagged() }
        pub mod tests { pub fn check() -> i32 { super::rules::recompute(&[1, 2, 3]) } }
    }
}
fn main() { println!("{} {}", acme::orders::total(&[1, 2]), acme::orders::tests::check()); }
