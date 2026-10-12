#!/usr/bin/env bash
# 57-01 re-run of the ticket repro (2026-08-23) against the CURRENT bsc, widened: operators, parens,
# flipped operands, constant arithmetic, and GUARDS (which share alternatives/1 with refinements).
root=$(cd "$(dirname "$0")/../../.." && pwd)
bsc="$root/compiler/_build/default/bin/bsc"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
# bsc writes <Module>.beam/.abstr into the CWD, so always run it from the scratch dir.
probe () { local n=$1 src=$2; mkdir -p "$work/$n"; printf 'module %s\n%s\n' "$n" "$src" > "$work/$n/a.bs"
  out=$(cd "$work" && "$bsc" "$work/$n/a.bs" 2>&1); if [ -z "$out" ]; then echo "$n: accepted"; else echo "$n: refused"; echo "$out" | head -${3:-3} | sed "s#$work/##;s/^/    /"; fi; }
echo "== refinements =="
probe RGeNeg   'type T = int where value >= -5'
probe RBoth    'type T = int where value >= -5 and value <= 5'
probe ROrNeg   'type T = int where value >= 1 or value <= -1'
probe ROrPos   'type T = int where value <= 3 or value >= 10'
probe RNe0     'type T = int where value != 0'
probe RFlip    'type T = int where -5 <= value'
probe RParen   'type T = int where value >= (-5)'
probe RSum     'type T = int where value >= 2 + 3'
probe RProd    'type T = int where value >= 2 * 3'
probe RFloat   'type T = float where value >= -5.0'
echo "== guards =="
probe GNeg 'public atom S(int n)
S(n) when n <= -1 -> :neg
S(n) when n >= 0 -> :nonneg' 4
probe GPos 'public atom S(int n)
S(n) when n <= 1 -> :neg
S(n) when n >= 2 -> :nonneg'
echo "== relational pattern =="
probe PNeg 'public atom S(int n)
S(<= -1) -> :neg
S(>= 0) -> :nonneg'
echo "== full diagnostic text =="
probe FullDiag 'type T = int where value >= -5' 9
