#!/usr/bin/env bash
# Ticket 60: Go's `internal/` path rule, the one mainstream directory-subtree who-may-name-this mechanism.
# Measures: enforced at compile time? what is the unit (the parent of the `internal` segment)? what is the diagnostic?
W=$(mktemp -d); cd "$W"; export GOFLAGS=-mod=mod GOPROXY=off GO111MODULE=on
mkdir -p shop/pricing/internal/rates shop/reports shop/pricing/sub
printf 'module ex.com/app\ngo 1.24\n' > go.mod
printf 'package rates\nfunc Rate() int { return 3 }\n' > shop/pricing/internal/rates/rates.go
printf 'package pricing\nimport "ex.com/app/shop/pricing/internal/rates"\nfunc Charge() int { return rates.Rate() }\n' > shop/pricing/pricing.go
printf 'package sub\nimport "ex.com/app/shop/pricing/internal/rates"\nfunc F() int { return rates.Rate() }\n' > shop/pricing/sub/sub.go
printf 'package reports\nimport "ex.com/app/shop/pricing/internal/rates"\nfunc G() int { return rates.Rate() }\n' > shop/reports/reports.go
for p in ./shop/pricing ./shop/pricing/sub ./shop/reports; do printf '%-22s ' $p; go build $p 2>&1 | head -2 | tr '\n' ' '; echo "exit=${PIPESTATUS[0]}"; done
