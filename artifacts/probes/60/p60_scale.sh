#!/usr/bin/env bash
# Ticket 60. What does the subtree check cost the checker?  N modules Shop.M0..Shop.M{N-1}; each `using`s its predecessor.
# `restrict/2` runs inside import_env (4 calls per module) and walks the World, so the worry is O(N^2).
# usage: p60_scale.sh EBIN N      (wall time of one bsc compile of the whole tree, best of 3)
. "$(dirname "$0")/../env.sh"; export BSC_EBIN=$1; N=$2
W=$(mktemp -d); S=$W/src; mkdir -p $S/Shop
for i in $(seq 0 $((N-1))); do mkdir -p $S/Shop/M$i; if [ $i -eq 0 ]; then
  printf 'module Shop.M0\n\npublic int F(int n)\nF(n) -> n\n' > $S/Shop/M0/m.bs
else
  printf 'module Shop.M%s\n\nusing Shop.M%s\n\npublic int F(int n)\nF(n) -> n\n' $i $((i-1)) > $S/Shop/M$i/m.bs
fi; done
best=999999
for r in 1 2 3; do s=$(date +%s%N); bsc --src-root $S -o $W/out $S/Shop/M$((N-1)) >/dev/null 2>&1 || { echo "compile failed"; exit 1; }; e=$(date +%s%N); t=$(( (e-s)/1000000 )); [ $t -lt $best ] && best=$t; done
echo "N=$N best=${best}ms"
