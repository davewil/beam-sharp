#!/usr/bin/env bash
# 60/j : Go's `internal` directory rule = exactly 'callee in a path segment, unit = subtree of the parent'. EXECUTED run (go in PATH).
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
export GOFLAGS=-mod=mod GOPATH="$w/gopath" GOCACHE="$w/cache" GO111MODULE=on GOPROXY=off
go version
mkdir -p shop/orders/internal/recompute shop/billing tools/rogue shop/orders/tests
printf 'module example.com/app\n\ngo 1.21\n' > go.mod
printf 'package recompute\n\nfunc Sum(x []int) int { s := 0; for _, v := range x { s += v }; return s }\n' > shop/orders/internal/recompute/r.go
printf 'package orders\n\nimport "example.com/app/shop/orders/internal/recompute"\n\nfunc Total(x []int) int { return recompute.Sum(x) }\n' > shop/orders/o.go
printf 'package tests\n\nimport "example.com/app/shop/orders/internal/recompute"\n\nvar _ = recompute.Sum\n' > shop/orders/tests/t.go
printf 'package billing\n\nimport "example.com/app/shop/orders/internal/recompute"\n\nvar _ = recompute.Sum\n' > shop/billing/b.go
printf 'package rogue\n\nimport "example.com/app/shop/orders/internal/recompute"\n\nvar _ = recompute.Sum\n' > tools/rogue/r.go
for p in shop/orders shop/orders/tests shop/billing tools/rogue; do echo "== go build ./$p"; go build ./$p 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"; done
