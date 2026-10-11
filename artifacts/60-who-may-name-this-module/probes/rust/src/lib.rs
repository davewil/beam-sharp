pub mod shop {
    pub mod orders {
        // visible to `shop` and everything below it, no further
        pub(in crate::shop) fn recompute_total(n: i32) -> i32 { n * 2 }
        pub fn apply(n: i32) -> i32 { recompute_total(n) + 1 }
    }
    pub mod reports {
        pub fn report(n: i32) -> i32 { super::orders::recompute_total(n) }   // inside `shop`: allowed
    }
}
pub mod elsewhere {
    pub fn poke(n: i32) -> i32 { crate::shop::orders::recompute_total(n) }   // outside `shop`: refused
}
