#!/usr/bin/env bash
# arith_diff.sh : does folding `-N` at the grammar (build A) change any RUN-TIME value? Runs the same
# expressions through the reference build and A and diffs the results. Control: a deliberately wrong
# value (`-7 / 2` expected -4) must make the comparison report a difference.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p $W/src/Ar
exprs=('-5' '-(-5)' '- 5' '3 - -5' '-5 + 3' '-2 * 3 - 1' '-7 / 2' '-7 % 2' '7 % -2' '7 / -2' '-(2 + 3)' '-(-(-5))' '0 - 5' '-0' '- -3' '2 - -2 * -2' '-5 / -2' '-x' '-x - -x' 'x * -3' '-1000000 * -1000000 * -1000000')
{ echo "module Ar"; i=0; for e in "${exprs[@]}"; do echo "public int E$i(int x)"; echo "E$i(x) -> $e"; i=$((i+1)); done; } > $W/src/Ar/a.bs
for spec in reference:$S/bsc-ebin A:$S/57/ebin-A; do
  n=${spec%%:*}; e=${spec#*:}; mkdir -p $W/o$n
  (cd $W/o$n && erl -noshell -pa $e -run bsc main $W/src/Ar/a.bs -run init stop 2>&1 | head -3)
  : > $W/res.$n; i=0
  for ex in "${exprs[@]}"; do
    v=$(cd $W/o$n && erl -noshell -pa $e -run bsc main $W/src/Ar/a.bs E$i 7 -run init stop 2>&1 | tail -1)
    echo "E$i  ($ex) with x=7  =>  $v" >> $W/res.$n; i=$((i+1))
  done
done
cat $W/res.A
echo "--- diff reference vs A (expect none):"; diff $W/res.reference $W/res.A && echo "identical"
echo "--- control: corrupt one value in A's results, diff must fire:"
sed 's/(-7 \/ 2) with x=7  =>  -3/(-7 \/ 2) with x=7  =>  -4/' $W/res.A > $W/res.bad; diff $W/res.reference $W/res.bad > /dev/null && echo "CONTROL FAILED: diff did not fire" || echo "control ok: diff fired"
