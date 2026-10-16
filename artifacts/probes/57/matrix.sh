#!/usr/bin/env bash
# 57 / matrix — which spellings of a signed bound does a given bsc accept?
#   matrix.sh PATH_TO_BSC
# Each row is a one-line type declaration compiled as its own module. Prints accepted/refused
# and, for refusals, the diagnostic tag line. Rows 1-5 re-run ticket 57's own table.
set -uo pipefail
BSC=${1:?bsc path}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
row() {  # name, source
  mkdir -p "$W/$1"; printf 'module %s\n%s\n' "$1" "$2" > "$W/$1/a.bs"
  out=$("$BSC" -o "$W/$1/out" "$W/$1/a.bs" 2>&1); rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ]; then s=accepted; else s="refused: $(echo "$out" | grep -m1 -o 'error: .*' | cut -c1-70)"; fi
  printf '%-34s %-46s %s\n' "$1" "$2" "$s"
}
row T57GeNeg      'type T = int where value >= -5'
row T57Band        'type T = int where value >= -5 and value <= 5'
row T57Outer       'type T = int where value >= 1 or value <= -1'
row T57Disjoint    'type T = int where value <= 3 or value >= 10'
row T57NeZero     'type T = int where value != 0'
row T57ParenNeg   'type T = int where value >= (-5)'
row T57Flip        'type T = int where -5 <= value'
row T57Sum         'type T = int where value >= 2 + 3'
row T57ZeroMinus  'type T = int where value >= 0 - 5'
row T57NegExpr    'type T = int where value >= -(5)'
row T57VarBound   'type T = int where value >= n'
row T57DoubleNeg  'type T = int where value >= - -5'
row T57PatRel     $'public atom Sign(int n)\nSign(<= -1) -> :neg\nSign(_) -> :nonneg'
row T57GuardNeg   $'public atom Sign(int n)\nSign(n) when n < -1 -> :neg\nSign(_) -> :nonneg'
row T57ExhGuard   $'public atom Sign(int n)\nSign(n) when n < -1 -> :neg\nSign(n) when n >= -1 -> :nonneg'
row T57ExhGuardPos  $'public atom Sign(int n)\nSign(n) when n < 1 -> :neg\nSign(n) when n >= 1 -> :nonneg'
row T57ExhGuardSum  $'public atom Sign(int n)\nSign(n) when n < 1 + 1 -> :neg\nSign(n) when n >= 2 -> :nonneg'
