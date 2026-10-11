#!/usr/bin/env bash
# Probe: Go's directory-subtree rule, the direct precedent for "variant B" (a path convention enforced by the toolchain).
export GOFLAGS=-mod=mod GOPROXY=off GOCACHE=$(mktemp -d)
cd "$(dirname "$0")/go" && go version
echo "--- orders/total (a descendant of orders/) imports orders/internal/pricing: expect OK"; go build ./shop/orders/total/ && echo "exit=0"
echo "--- reports (a sibling subtree) imports it: expect refusal"; go build ./shop/reports/ 2>&1; echo "exit=$?"
