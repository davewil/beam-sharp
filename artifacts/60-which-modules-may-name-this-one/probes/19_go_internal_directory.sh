#!/bin/bash
# Go 1.24.7: `internal` is a DIRECTORY NAME. A package under .../x/internal/... may be imported only by code
# rooted at .../x/ . No keyword, no declaration -- the path is the declaration. Run, not recalled.
export GOFLAGS=-mod=mod GOPATH=/tmp/gopath60 GOCACHE=/tmp/gocache60 GOTOOLCHAIN=local GOPROXY=off
W=/tmp/go60; rm -rf $W; mkdir -p $W/acme/orders/internal/rules $W/acme/orders/tests $W/acme/billing $W/acme/orders/internal/deep/internal/leaf; cd $W
go version
cat > go.mod <<'EOT'
module example.com/shop
go 1.24
EOT
cat > acme/orders/internal/rules/rules.go <<'EOT'
package rules
func Recompute(xs []int) int { s := 0; for _, x := range xs { s += x }; return s }
EOT
cat > acme/orders/orders.go <<'EOT'
package orders
import "example.com/shop/acme/orders/internal/rules"
func Total(xs []int) int { return rules.Recompute(xs) }
EOT
cat > acme/orders/tests/tests.go <<'EOT'
package tests
import "example.com/shop/acme/orders/internal/rules"
func Check() int { return rules.Recompute([]int{1, 2, 3}) }
EOT
cat > acme/billing/billing.go <<'EOT'
package billing
import "example.com/shop/acme/orders/internal/rules"
func Invoice() int { return rules.Recompute([]int{1}) }
EOT
echo "## inside the subtree rooted at acme/orders (orders, and orders/tests):"; go build ./acme/orders/... ; echo "exit=$?"
echo "## a sibling, acme/billing:"; go build ./acme/billing/ 2>&1; echo "exit=$?"
echo "## two internal elements: acme/orders/internal/deep/internal/leaf -- who may import it?"
cat > acme/orders/internal/deep/internal/leaf/leaf.go <<'EOT'
package leaf
func X() int { return 1 }
EOT
mkdir -p acme/orders/internal/deep/x acme/orders/internal/other
cat > acme/orders/internal/deep/x/x.go <<'EOT'
package x
import "example.com/shop/acme/orders/internal/deep/internal/leaf"
func Y() int { return leaf.X() }
EOT
cat > acme/orders/internal/other/other.go <<'EOT'
package other
import "example.com/shop/acme/orders/internal/deep/internal/leaf"
func Z() int { return leaf.X() }
EOT
echo "-- importer under .../deep (allowed by the LAST internal):"; go build ./acme/orders/internal/deep/x/ 2>&1; echo "exit=$?"
echo "-- importer under .../orders/internal but outside .../deep:"; go build ./acme/orders/internal/other/ 2>&1; echo "exit=$?"
echo "## and Go does not stop the BEAM-style back door: the symbol is an ordinary exported name in the compiled package"
go tool nm $(go list -export -f '{{.Export}}' ./acme/orders/internal/rules/) 2>/dev/null | grep -c Recompute
