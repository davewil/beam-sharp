#!/usr/bin/env bash
# P1: which boundary guards does the reference compiler emit on a PRIVATE function today?
source "$(dirname "$0")/env.sh"
EBIN=${1:-/tmp/bs59-build/ebin-base}; [ -d "$EBIN" ] || build_compiler "$EBIN"
OUT=$(mktemp -d); mkdir -p "$OUT/P1"; cp "$PROBES/src/p1_private_guards.bs" "$OUT/P1/p1.bs"
bsc_in "$EBIN" "$OUT" --src-root "$OUT" "$OUT/P1" 2>&1 | grep -v '^$'
"$PROBES/dump.escript" "$OUT/P1.beam" 2>/dev/null || "$PROBES/dump.escript" "$(ls "$OUT"/*.beam "$OUT"/*/*.beam | head -1)"
