#!/usr/bin/env bash
# Reproduce ticket 57's table (and extras) against the prebuilt bsc.
# Usage: bash run_table.sh   (from anywhere)
HERE="$(cd "$(dirname "$0")" && pwd)"
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
n=0; cd "$W"
while IFS= read -r pred; do
  [ -z "$pred" ] && continue
  n=$((n+1)); d="$W/M$n"; mkdir -p "$d"
  printf 'module M%s\n\ntype T = int where %s\n\npublic int F(T x)\n\nF(x) -> 1\n' "$n" "$pred" > "$d/m$n.bs"
  out="$("$BSC" "$d" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then v=ACCEPTED; else v="REFUSED: $(echo "$out" | head -1 | sed 's/^[^ ]* //')"; fi
  printf '%-48s %s\n' "$pred" "$v"
done < "$HERE/preds.txt"
