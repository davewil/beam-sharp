#!/usr/bin/env bash
# 60/m : Rust's pub(in path) = 'callee names the subtree that may name it'. EXECUTED if rustc is on PATH, else prints SKIPPED.
command -v rustc >/dev/null || { echo "SKIPPED: no rustc"; exit 0; }
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"; rustc --version
cat > m.rs <<'EOF'
mod shop {
    pub mod orders {
        pub mod recompute {
            pub(in crate::shop) fn sum(x: &[i32]) -> i32 { x.iter().sum() }
        }
        pub fn total(x: &[i32]) -> i32 { recompute::sum(x) }
    }
    pub mod billing {
        pub fn charge(x: &[i32]) -> i32 { super::orders::recompute::sum(x) }   // under shop: allowed
    }
}
mod tools {
    pub fn rogue(x: &[i32]) -> i32 { crate::shop::orders::recompute::sum(x) }  // outside shop: refused
}
fn main() { println!("{}", shop::orders::total(&[1,2,3]) + shop::billing::charge(&[1]) + tools::rogue(&[1])); }
EOF
rustc m.rs -o m 2>&1; echo "exit=$?"
