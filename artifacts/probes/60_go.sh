#!/usr/bin/env bash
# CLAIM: Go's `internal` path segment (the precedent for a path-derived rule): `a/b/internal/x` may be imported only by
#   code rooted at `a/b`; the check is the importer's build; siblings of `a/b` and outsiders are refused; the callee needs no declaration.
# REFUTED IF: shop/billing (sibling of shop/orders) or outsider/audit compiles when importing shop/orders/internal/recompute;
#   or shop/orders itself is refused. CONTROL: shop/orders -> its own internal compiles; shop/billing -> shop/internal compiles (rooted at shop).
export PATH=/usr/local/go/bin:$PATH; export GOFLAGS=-mod=mod GOTOOLCHAIN=local GOPROXY=off
S=$(mktemp -d /tmp/probe60go.XXXXXX); cd $S; go version
cat > go.mod <<'T'
module example.com/m
go 1.20
T
mkdir -p shop/orders/internal/recompute shop/internal/tax shop/billing outsider/audit
echo 'package recompute
func Total(l []int) int { s := 0; for _, x := range l { s += x }; return s }' > shop/orders/internal/recompute/r.go
echo 'package tax
func On(c int) int { return c / 10 }' > shop/internal/tax/t.go
echo 'package orders
import ("example.com/m/shop/orders/internal/recompute"; "example.com/m/shop/internal/tax")
func Total(l []int) int { return recompute.Total(l) + tax.On(1) }' > shop/orders/o.go
echo 'package billing
import "example.com/m/shop/internal/tax"
func Inv() int { return tax.On(1000) }' > shop/billing/b.go
echo "=== green: orders->own internal, billing->shop/internal"; go build ./shop/orders ./shop/billing; echo "exit $?"
echo 'package billing
import "example.com/m/shop/orders/internal/recompute"
func Bad() int { return recompute.Total(nil) }' > shop/billing/bad.go
echo "=== red: sibling billing -> shop/orders/internal"; go build ./shop/billing 2>&1; echo "exit $?"
rm shop/billing/bad.go
echo 'package audit
import "example.com/m/shop/internal/tax"
func Bad() int { return tax.On(1) }' > outsider/audit/a.go
echo "=== red: outsider -> shop/internal"; go build ./outsider/audit 2>&1; echo "exit $?"
