#!/usr/bin/env bash
# Probe 05: the two installed languages that have a *subtree-scoped* visibility rule (Go `internal/`,
# Rust `pub(in path)`), to see what the rule actually refuses -- including the text-prefix trap.
export PATH=$PATH:/usr/local/go/bin:/root/.cargo/bin
T=$(mktemp -d); cd "$T"
go version; rustc --version
echo "############ Go: internal/ (rule: importer must be inside the tree rooted at internal's PARENT)"
mkdir -p orders/internal/recompute orders/pricing billing ordersextra && cat > go.mod <<'EOS'
module example.com/shop
go 1.24
EOS
echo 'package recompute
func Recompute(n int) int { return n * 3 }' > orders/internal/recompute/r.go
echo 'package orders
import "example.com/shop/orders/internal/recompute"
func Total(n int) int { return recompute.Recompute(n) + 1 }' > orders/o.go
echo 'package pricing
import "example.com/shop/orders/internal/recompute"
func Priced(n int) int { return recompute.Recompute(n) + 100 }' > orders/pricing/p.go
echo 'package billing
import "example.com/shop/orders/internal/recompute"
func Bill(n int) int { return recompute.Recompute(n) }' > billing/b.go
echo 'package ordersextra
import "example.com/shop/orders/internal/recompute"
func Extra(n int) int { return recompute.Recompute(n) }' > ordersextra/e.go
for p in orders orders/pricing billing ordersextra; do echo "--- go build ./$p"; GOFLAGS=-mod=mod GOPROXY=off go build ./$p 2>&1; echo "exit=$?"; done
echo "--- go test: a _test.go beside the internal package (tests in the subtree)"
echo 'package recompute
import "testing"
func TestR(t *testing.T) { if Recompute(2) != 6 { t.Fatal("x") } }' > orders/internal/recompute/r_test.go
GOPROXY=off go test ./orders/internal/recompute 2>&1; echo "exit=$?"

echo "############ Rust: pub(in path) / pub(crate) / pub(super)"
cat > r.rs <<'EOS'
mod orders {
    pub mod internal { pub(in crate::orders) fn recompute(n: i32) -> i32 { n * 3 } }
    pub fn total(n: i32) -> i32 { internal::recompute(n) + 1 }
    pub mod pricing { pub fn priced(n: i32) -> i32 { super::internal::recompute(n) + 100 } }
}
mod billing { pub fn bill(n: i32) -> i32 { crate::orders::internal::recompute(n) } }
fn main() { println!("{}", orders::total(1)); }
EOS
rustc --edition 2021 r.rs -o r 2>&1 | grep -E '^(error|warning: unused)|-->|private' | head -8
