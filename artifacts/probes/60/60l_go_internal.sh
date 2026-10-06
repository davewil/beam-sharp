#!/usr/bin/env bash
# PROBE 60l -- ticket 60 (ENG-242). Go 1.24.7 `internal/` (the one surveyed neighbour that actually
# REFUSES a caller): rule at /usr/local/go/src/cmd/go/internal/load/pkg.go:1472-1578
# ("An import of a path containing the element internal is disallowed if the importing code is
#  outside the tree rooted at the parent of the internal directory", pkg.go:1473-1475).
#   L1 importer inside the parent's tree (lab/core/sub imports lab/core/internal/x): builds, exit 0.
#   L2 importer outside it (lab/web imports lab/core/internal/x): refused, exit != 0, message cited.
#   L3 CONTROL: the same web importing a non-internal package lab/core/api builds, exit 0.
#      export data of x supplied directly is not asked about internal (see output).  [not run: see Not verified]
set -uo pipefail
export PATH="$PATH:/usr/local/go/bin"
command -v go >/dev/null || { echo "go missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
export GOFLAGS=-mod=mod GOPROXY=off GOCACHE="$W/cache" GOPATH="$W/gopath" GO111MODULE=on
mkdir -p lab/core/internal/x lab/core/sub lab/core/api lab/web lab/web2
cat > go.mod <<'E'
module example.com/lab
go 1.24
E
echo 'package x
func Secret() int { return 7 }' > lab/core/internal/x/x.go
echo 'package sub
import "example.com/lab/lab/core/internal/x"
func S() int { return x.Secret() }' > lab/core/sub/sub.go
echo 'package api
func A() int { return 1 }' > lab/core/api/api.go
echo 'package web
import "example.com/lab/lab/core/internal/x"
func W() int { return x.Secret() }' > lab/web/web.go
echo 'package web2
import "example.com/lab/lab/core/api"
func W() int { return api.A() }' > lab/web2/web2.go
for p in core/sub web web2; do
  out=$(go build ./lab/$p 2>&1); echo "go build lab/$p: exit=$?"; [ -n "$out" ] && echo "$out" | sed 's/^/    /' | head -3
done
