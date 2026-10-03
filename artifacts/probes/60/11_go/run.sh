#!/bin/sh
# Probe 60/11: Go 1.24.7's `internal` directory rule, the precedent for an `Internal` path segment.
export PATH=/usr/local/go/bin:$PATH GOFLAGS=-mod=mod GOCACHE=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/gocache GOPATH=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/gopath
cd "$(dirname "$0")/mod"
for p in billing billing/reconcile orders spy; do echo "== go build ./$p"; go build ./$p 2>&1; echo "exit=$?"; done
echo "== the rule, from the installed source: cmd/go/internal/load/pkg.go"
grep -n 'is disallowed if the importing code is outside the tree' /usr/local/go/src/cmd/go/internal/load/pkg.go
grep -n 'str.HasPathPrefix(importerPath, parentOfInternal)' /usr/local/go/src/cmd/go/internal/load/pkg.go
