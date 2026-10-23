#!/usr/bin/env bash
# PROBE 64b — a lookup over map<string, term> whose stored values are the two sentinels.
# Treatment: Lookup (hand-rolled tagged success, the compiler's own hint). Control: Bare (absence = :nothing at type term).
# Expected from the claim "the bare shape lies": Bare reports key "a" (stored :nothing) as absent; Lookup does not.
set -uo pipefail
: "${BSC:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/64b"
echo "== Lookup (tagged): bsc --api =="; "$BSC" --api "$HERE/Lookup/Lookup.bs"
for k in a b c zzz; do printf 'Lookup.Describe(%-3s) = ' "$k"; "$BSC" "$HERE/Lookup/Lookup.bs" Describe "\"$k\"" 2>&1 | tail -1; done
echo "== Bare (control, compiles with no diagnostic) =="
for k in a b c zzz; do printf 'Bare.Describe(%-3s)   = ' "$k"; "$BSC" "$HERE/Bare/Bare.bs" Describe "\"$k\"" 2>&1 | tail -1; done
echo "(stored: a=:nothing  b=:error  c=5  zzz=missing)"
