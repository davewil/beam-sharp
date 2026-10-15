#!/usr/bin/env bash
# 57_guard_runtime -- worry in the ticket: narrowing the grammar at one site makes a refinement and a
# guard (same `expr`) disagree. Test: the SAME guard `n >= -5` run on stock / gramA / gramB / chk gives the
# same RUNTIME answers on -6, -5, 0 (the guard is emitted, never read by the checker at run time), and
# the exhaustiveness answer (G01) moves identically for guard and refinement in each build.
# REFUTED (worry is real) by: runtime answers differing between builds, OR a build in which the refinement
# row reads accepted while the guard-exhaustiveness row reads refused (or vice versa) for the SAME literal.
# usage: V57=<dir> 57_guard_runtime.sh
. "$(dirname "$0")/env.sh"; . "$(dirname "$0")/57_lib.sh"; : "${V57:?}"
w=$(mktemp -d "${TMPDIR:-/tmp}/p57g.XXXXXX"); mkdir -p "$w/M"
printf 'module M\npublic atom F(int n)\nF(n) when n >= -5 -> :a\nF(n) -> :b\n' > "$w/M/a.bs"
for v in stock gramA gramB gramC chk; do
  b=$V57/$v/_build/default/bin/bsc
  printf '%-6s run F(-6),F(-5),F(0) = ' $v; for a in -6 -5 0; do printf '%s ' "$("$b" "$w/M" F $a 2>&1 | tail -1)"; done; echo
  try "$b" "   refinement  >= -5"  'type T = int where value >= -5'
  try "$b" "   guard-exhaust n>=-5/n<-5" $'public atom G(int n)\nG(n) when n >= -5 -> :a\nG(n) when n < -5 -> :b'
done
