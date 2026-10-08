#!/bin/bash
# S4 (extra neighbour, not in the brief's list): Go's path-derived `internal/` rule, executed.
export PATH=$PATH:/usr/local/go/bin GOFLAGS=-mod=mod GOPROXY=off GOCACHE=$(mktemp -d)
D=$(mktemp -d); cd $D
go version
cat > go.mod <<'EOM'
module example.com/acme
go 1.20
EOM
mkdir -p orders/internal/pricing billing orders/sub
cat > orders/internal/pricing/p.go <<'EOM'
package pricing
func Compute(n int) int { return n * 2 }
EOM
cat > orders/o.go <<'EOM'
package orders
import "example.com/acme/orders/internal/pricing"
func Total(n int) int { return pricing.Compute(n) + 1 }
EOM
cat > orders/sub/s.go <<'EOM'
package sub
import "example.com/acme/orders/internal/pricing"
func Sub(n int) int { return pricing.Compute(n) + 2 }
EOM
cat > billing/b.go <<'EOM'
package billing
import "example.com/acme/orders/internal/pricing"
func Due(n int) int { return pricing.Compute(n) }
EOM
for p in orders orders/sub billing; do echo "--- go build ./$p"; go build ./$p 2>&1 | head -3; echo "exit ${PIPESTATUS[0]}"; done
rm -rf $D
