#!/usr/bin/env bash
# PROBE 64c — can an author declare an always-tagged generic sibling Maybe<T> TODAY, at term and nested,
# and does exhaustiveness still prove the absent arm? Control: the same switch with the :nothing arm removed.
set -uo pipefail
: "${BSC:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/64c"
echo "== bsc --api =="; "$BSC" --api "$HERE/Maybe/Maybe.bs"
for n in 0 1 2; do
  printf 'Which(%s) = ' $n; "$BSC" "$HERE/Maybe/Maybe.bs" Which $n 2>&1 | tail -1
  printf 'Deep(%s)  = ' $n; "$BSC" "$HERE/Maybe/Maybe.bs" Deep $n 2>&1 | tail -1
done
echo "== control: the :nothing arm removed (must be refused as non-exhaustive) =="
"$BSC" "$HERE/Missing/Missing.bs" Which 0 2>&1 | sed -n 1,3p
echo "== and the lowercase spelling is not writable by a user =="
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/L"
printf 'module L\n\ntype maybe<T> = (:some, T) | :nothing\n\npublic int Go(int i)\nGo(i) -> 1\n' > "$W/L/L.bs"
"$BSC" --api "$W/L/L.bs" 2>&1 | sed -n 1,2p
