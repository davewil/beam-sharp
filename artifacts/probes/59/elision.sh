#!/usr/bin/env bash
# Probe 59d: does erlc itself elide a private function's guard when every caller has proved the type?
# 'abstract' = the guard is in the emitted abstract code; 'beam' = it survives in the optimised beam.
cd "$(dirname "$0")"
for v in base B; do
  echo "=== emitter $v"
  for f in "Inner 1 pass-through-from-guarded-export" "Go 2 private-recursive-loop" "Cap 1 captured-as-fun/UNKNOWN-callers" "Tot 1 record-tag,pass-through-from-guarded-export"; do
    set -- $f
    ab=$(./show.escript out/Chain/$v/Chain.beam | awk -v fn="'$1'" 'index($0,fn"(")==1{p=1} p{print} p&&/\.$/{exit}' | grep -c -E "is_integer|map_get\('Kind'")
    bm=$(./disasm.escript out/Chain/$v/Chain.beam $1 $2 | grep -c -E "test,is_integer|is_eq_exact")
    printf '  %-4s %-3s %-44s abstract_test=%s beam_test=%s\n' "$1" "$2" "$3" "$([ $ab -gt 0 ] && echo yes || echo no)" "$([ $bm -gt 0 ] && echo yes || echo no)"
  done
done
