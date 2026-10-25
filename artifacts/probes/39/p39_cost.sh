#!/usr/bin/env bash
# Ticket 39. What does `inline` cost? Compile every example module with one emitter build: total .beam bytes and wall time
# (a separate VM per module, so boot cost is the same for every build and cancels in the comparison).
# usage: p39_cost.sh LABEL EBIN
. "$(dirname "$0")/../env.sh"; L=$1; export BSC_EBIN=$2; ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT=$(mktemp -d); n=0; fails=0
mods=$(ls -d "$ROOT"/compiler/examples/*/ "$ROOT"/aoc/2025/Day01 "$ROOT"/aoc/bench/Day01 2>/dev/null)
s=$(date +%s.%N)
for m in $mods; do d=$OUT/$(basename $(dirname $m/x))-$n; n=$((n+1)); mkdir -p $d; bsc --src-root "$ROOT/compiler/examples" -o $d $m >/dev/null 2>&1 || fails=$((fails+1)); done
e=$(date +%s.%N)
bytes=$(find $OUT -name '*.beam' -printf '%s\n' | paste -sd+ | bc)
printf '%-5s modules=%s not-compiled=%s (two are aoc/ paths outside --src-root, one is a namespace dir; not real failures) beam-bytes=%s wall=%.1fs\n' $L $n $fails $bytes $(echo "$e - $s" | bc)
