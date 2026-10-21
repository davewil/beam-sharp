#!/bin/sh
D=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?set BSC}
for f in Describe DescribeBare; do for kv in '[(:a, :nothing)]' '[(:b, 1)]'; do
  printf '%-12s k=:a kvs=%-18s -> ' "$f" "$kv"; "$BSC" "$D/bs/Lookup" "$f" ":a" "$kv" 2>&1 | tail -1; done; done
