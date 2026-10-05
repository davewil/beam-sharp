#!/usr/bin/env bash
# NEIGHBOUR (not on the ticket's list; installed, so measured): Go's `internal` DIRECTORY rule.
# It is a subtree rule decided from the import path alone: the closest existing thing to the
# "subtree of the source root" the ticket proposes, so the false-friend question is live.
# REFUTED (as an enforcing, path-decided rule) IF: `go build` accepts the outsider's import of
# .../shop/internal/calc.
. "$(dirname "$0")/lib.sh"
G="$WORK/go"; rm -rf "${G:?}"; mkdir -p "$G/shop/internal/calc" "$G/shop/reports" "$G/outsider" "$G/outsider_ok"; cd "$G" || exit 1
go version
export GOFLAGS=-mod=mod GOPROXY=off GOTOOLCHAIN=local GO111MODULE=on GOCACHE="$G/.cache" GOPATH="$G/.gopath"
printf 'module example.com/m\n\ngo 1.21\n' > go.mod
cat > shop/internal/calc/calc.go <<'EOT'
package calc

func Recompute(xs []int) int { s := 0; for _, x := range xs { s += x }; return s }
EOT
cat > shop/reports/r.go <<'EOT'
package reports

import "example.com/m/shop/internal/calc"

func Report(xs []int) int { return calc.Recompute(xs) }
EOT
cat > outsider/o.go <<'EOT'
package outsider

import "example.com/m/shop/internal/calc"

func Peek(xs []int) int { return calc.Recompute(xs) }
EOT
echo '--- go build ./shop/... (inside the subtree: control)'; go build ./shop/... ; echo "exit=$?"
echo '--- go build ./outsider (outside the subtree)'; go build ./outsider 2>&1 | head -5; rc=${PIPESTATUS[0]}; echo "exit=$rc"
echo '--- go vet cannot be used to dodge it; and reflection/plugin dynamic calls are outside the rule: not measured'
[ "$rc" -ne 0 ]; verdict "go-internal-dir-is-enforced-from-the-path" $?
