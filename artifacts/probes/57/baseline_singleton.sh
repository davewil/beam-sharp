#!/usr/bin/env bash
# Is "bad range type" on a single-value refinement pre-existing (no negative literal involved)?
BSC=${1:?bsc}
W=$(mktemp -d)
for pred in 'value == 3' 'value > 0 and value < 2' 'value == 0' 'value > 2 and value < 4' 'value >= 3 and value <= 3'; do
  mkdir -p $W/P; printf 'module P\n\ntype T = int where %s\n\npublic atom F(T x)\n\nF(x) -> :ok\n' "$pred" > $W/P/p.bs
  out=$(cd $W && "$BSC" -o $W/out P 2>&1); printf 'rc=%s  %-28s %s\n' $? "$pred" "$(echo "$out"|head -1)"
done
