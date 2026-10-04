mod acme {
    pub mod orders {
        mod rules {
            pub fn recompute(xs: &[i32]) -> i32 { xs.iter().sum() }
            pub(in crate::acme::orders) fn tagged() -> i32 { 7 }
        }
        pub mod rules2 { pub(in crate::acme::orders) fn helper() -> i32 { 1 } pub fn open() -> i32 { 2 } }
        pub fn total(xs: &[i32]) -> i32 { rules::recompute(xs) }
    }
    pub mod billing {
        pub fn invoice() -> i32 { super::orders::rules::recompute(&[1]) }   // sibling reaches into a private module
        pub fn invoice2() -> i32 { super::orders::rules2::helper() }       // sibling calls a pub(in ..) function
    }
}
fn main() { println!("{}", acme::billing::invoice() + acme::billing::invoice2()); }
