#!/usr/bin/env bash
# NEIGHBOUR (installed, measured): Rust `pub(in path)` / `pub(crate)` is a PER-ITEM marker that carries a PATH
# as its scope: the shape of candidate C with the scope written out instead of fixed.
# REFUTED IF: rustc accepts the call from outside the named path.
. "$(dirname "$0")/lib.sh"
R="$WORK/rust"; rm -rf "${R:?}"; mkdir -p "$R"; cd "$R" || exit 1
rustc --version
cat > ok.rs <<'EOT'
mod shop {
    pub mod internal { pub(in crate::shop) fn recompute(xs: &[i32]) -> i32 { xs.iter().sum() } }
    pub mod reports { pub fn report(xs: &[i32]) -> i32 { super::internal::recompute(xs) } }
}
fn main() { println!("{}", shop::reports::report(&[1,2,3])); }
EOT
cat > bad.rs <<'EOT'
mod shop {
    pub mod internal { pub(in crate::shop) fn recompute(xs: &[i32]) -> i32 { xs.iter().sum() } }
}
mod outsider { pub fn peek(xs: &[i32]) -> i32 { crate::shop::internal::recompute(xs) } }
fn main() { println!("{}", outsider::peek(&[1,2,3])); }
EOT
echo '--- control (caller inside crate::shop)'; rustc ok.rs -o ok 2>&1 | head -5 && ./ok; echo "exit=$?"
echo '--- caller outside crate::shop'; out=$(rustc bad.rs -o bad 2>&1); rc=$?; echo "$out" | head -12; echo "exit=$rc"
[ "$rc" -ne 0 ]; verdict "rust-pub-in-path-is-enforced" $?
