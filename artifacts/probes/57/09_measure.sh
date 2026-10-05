#!/usr/bin/env bash
# 09 -- measurements. (a) the AST shape each variant hands the checker;
# (b) compile time of a refinement-heavy module (median of 7 wall-clock runs,
# VM start-up measured on an empty module and reported beside it, because it
# dominates); (c) patch size (printed by 00_build.sh; repeated here).
# REFUTES "a checker fold costs compile time": c1/c2 median more than ~10% above
# base on P1 (non-negative refinements, where the fold finds nothing to fold).
# Run it on an otherwise idle machine: 10_eunit.sh must NOT be running.
. "$(dirname "$0")/lib.sh"
mkdir -p "$OUT/ast"
echo "== (a) AST of the refinement predicate, as parsed by each variant's own bs_parser"
for v in base g1 g1b c1 c2; do
  printf 'module M\ntype T = int where value >= -5 and value <= 5\n' > "$OUT/ast/a_$v.bs"
  printf '%-5s ' $v; escript "$OUT/ast.escript" "$(ebin_of $v)" "$OUT/ast/a_$v.bs" 2>&1 | tr -s ' \n' ' '; echo
done
gen () { # N signed(0|1) -> module Heavy source
  python3 - "$1" "$2" <<'PY'
import sys
n=int(sys.argv[1]); signed=int(sys.argv[2])
out=["module Heavy",""]
for k in range(n):
    lo = f"-{k+1}" if signed else "0"
    out.append(f"type T{k} = int where value >= {lo} and value <= {k+10}")
    out.append(f"public int F{k}(T{k} x)")
    out.append(f"F{k}(x) -> x")
print("\n".join(out))
PY
}
mkdir -p "$OUT/heavy/Heavy" "$OUT/heavy/Empty"
printf 'module Empty\npublic int F(int x)\nF(x) -> x\n' > "$OUT/heavy/Empty/a.bs"
gen 300 0 > "$OUT/heavy/Heavy/a.bs"; cp "$OUT/heavy/Heavy/a.bs" "$OUT/heavy/P1.bs"
gen 300 1 > "$OUT/heavy_signed.bs"
median () { sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }
timeit () { # variant dir -> median ms over 7 runs; prints "FAIL" if a run fails
  local v=$1 d=$2 i t s ts=""
  for i in 1 2 3 4 5 6 7; do
    s=$(date +%s%N); "$(bsc_of $v)" -o "$OUT/heavy/o_$v" "$d" >/dev/null 2>&1 || { echo FAIL; return; }
    t=$(( ($(date +%s%N) - s) / 1000000 )); ts="$ts $t"
  done; echo $ts | tr ' ' '\n' | median
}
echo "== (b) compile time, median of 7, milliseconds"
printf '%-5s %10s %14s %16s\n' variant "empty(VM)" "P1:300 nonneg" "P2:300 signed"
for v in base g1 g1b c1 c2; do
  e=$(timeit $v "$OUT/heavy/Empty"); p1=$(timeit $v "$OUT/heavy/Heavy")
  mkdir -p "$OUT/heavy/Signed"; cp "$OUT/heavy_signed.bs" "$OUT/heavy/Signed/a.bs"; sed -i 's/^module Heavy/module Signed/' "$OUT/heavy/Signed/a.bs"
  p2=$(timeit $v "$OUT/heavy/Signed")
  printf '%-5s %10s %14s %16s\n' $v "$e" "$p1" "$p2"
done
echo "(FAIL in P2 for base/g1b-less variants is the ticket itself: base cannot read a negative bound)"
