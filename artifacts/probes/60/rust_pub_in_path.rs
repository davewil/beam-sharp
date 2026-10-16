mod shop {
    pub mod rows { pub(in crate::shop) fn recompute() -> i32 { 1 } }
    pub mod billing { pub fn total() -> i32 { super::rows::recompute() } }
}
mod other { pub fn poke() -> i32 { crate::shop::rows::recompute() } }
fn main() { println!("{} {}", shop::billing::total(), other::poke()); }
