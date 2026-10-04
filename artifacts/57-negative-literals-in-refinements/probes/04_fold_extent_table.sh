#!/usr/bin/env bash
# The "how far does the fold go" table: refinement predicates the sub-decision is about.
# Run against any bsc: BSC=/path/to/bsc bash 04_fold_extent_table.sh
source "$(dirname "$0")/lib.sh"
mk () { printf '\ntype T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
i=0
while IFS= read -r pred; do
  i=$((i+1)); r=$(probe "P$i" "$(mk "$pred")" 2>&1)
  v=$(printf '%s\n' "$r" | head -1 | awk '{print $2}')
  e=$(printf '%s\n' "$r" | grep -o 'error: .*' | head -1)
  printf '%-34s %-14s %s\n' "$pred" "$v" "$e"
done <<'PREDS'
value >= 0 and value <= 255
value >= -5
-5 <= value
value > -5 and value < 5
value == -3
value != -3
value >= 1 or value <= -1
value >= 2 + 3
value >= -(5)
value >= - -5
value >= (-5)
value >= 0 - 5
value >= 2 * 3
value >= 10 / 2
value >= 7 % 4
value >= n
value >= 5 - value
value + 1 >= 5
value >= -5 and value <= -10
value >= -5.0
PREDS
