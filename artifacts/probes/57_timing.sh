#!/usr/bin/env bash
# 57_timing -- compile-time cost of the three builds. Claim: no measurable cost. REFUTED by a
# patched build's median exceeding stock's by more than stock's own run-to-run spread.
# Two sources: COMMON (no negative literal; compiles on all four) and SIGNED (patched only).
# in-VM n=2000 lex+parse, n=500 check; CLI wall clock n=9 (includes ~VM start, which dominates).
# usage: V57=<dir from 57_build_variants.sh> 57_timing.sh
. "$(dirname "$0")/env.sh"; here=$(cd "$(dirname "$0")" && pwd)
: "${V57:?run 57_build_variants.sh and export V57}"
w=$(mktemp -d "${TMPDIR:-/tmp}/p57t.XXXXXX"); mkdir -p "$w/C" "$w/S"
gen () {  # $1 = lower bound literal text ; 30 clauses with guards and relational patterns
  echo "module $2"; echo "type D = int where value >= $1 and value <= 100"
  echo "public atom Cls(D d)"
  for i in $(seq 1 30); do echo "Cls(d) when d >= $i and d < $((i+1)) -> :a$i"; done
  echo "Cls(<= 0) -> :low"; echo "Cls(>= 31) -> :hi"
  echo "public atom Gd(int n)"; for i in $(seq 1 30); do echo "Gd(n) when n == $i -> :g$i"; done; echo "Gd(n) -> :none"
}
gen 0 C > "$w/C/a.bs"; gen -100 S > "$w/S/a.bs"
echo "sanity: COMMON on stock must be accepted; SIGNED on stock must be refused:"
"$V57/stock/_build/default/bin/bsc" "$w/C" 2>&1 | grep -c "error" ; echo "(end of stock diagnostics for COMMON: warnings only)"
"$V57/stock/_build/default/bin/bsc" "$w/S" 2>&1 | head -1
for src in C S; do
  echo "=== source $src ($( [ $src = C ] && echo 'COMMON, lower bound 0' || echo 'SIGNED, lower bound -100'))"
  for v in stock stock gramA gramB gramC chk; do
    if [ $src = S ] && [ $v = stock ]; then echo "stock  (refused by design: opaque_refinement; not timed)"; continue; fi
    printf '%-6s ' $v; escript "$here/57_timing.escript" "$V57/$v/_build/default/lib/bsc/ebin" "$w/$src/a.bs" 2000 2>&1 | tail -1
  done
done
echo "=== CLI wall clock, n=9, ms (COMMON source; second 'stock' row is the noise control)"
for v in stock stock gramA gramB gramC chk; do
  ts=(); for i in $(seq 1 9); do s=$(date +%s%N); "$V57/$v/_build/default/bin/bsc" "$w/C" >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n)); printf '%-6s min=%sms median=%sms\n' $v "${sorted[0]}" "${sorted[4]}"
done
