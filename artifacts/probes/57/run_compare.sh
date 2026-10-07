#!/usr/bin/env bash
# Run the predicate table + guard probe on: current bsc, variant A (parser folds -INT), variant B (checker folds int arithmetic).
HERE="$(cd "$(dirname "$0")" && pwd)"
CUR=/home/user/beam-sharp/compiler/_build/default/bin/bsc
for t in cur A B; do
  b=$CUR; [ $t != cur ] && b="$HERE/work/$t/_build/default/bin/bsc"
  BSC=$b bash "$HERE/run_table.sh" > "$HERE/table_$t.out"
  BSC=$b bash "$HERE/run_guard.sh" > "$HERE/guard_$t.out" 2>&1
done
printf '%-36s %-9s %-9s %-9s\n' predicate current A-parser B-checker
i=0; while IFS= read -r p; do i=$((i+1))
  f() { sed -n ${i}p "$HERE/table_$1.out" | grep -q ACCEPTED && echo ok || echo REFUSED; }
  printf '%-36s %-9s %-9s %-9s\n' "$p" $(f cur) $(f A) $(f B)
done < "$HERE/preds.txt"
echo; for t in cur A B; do echo "guard probe, $t:"; grep -E "^== |rc=" "$HERE/guard_$t.out" | paste -sd' ' | sed 's/== /\n  /g'; done
