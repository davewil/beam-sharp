#!/usr/bin/env bash
# Probe 59-F: the BEST case for BEAM erasure of a widened int kind test -- a hot
# PRIVATE self-recursive loop whose only caller is an exported function whose own
# guard is visible to the BEAM type pass. Does the guard survive into the Code
# chunk? (It is NOT the worst case: see ListInt/ListRange in run-cost.sh, where the
# argument comes out of a list and the pass cannot see it.) head = shipped; widen = PROTOTYPE DELTA (int test on private too).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
erlc -o "$W" "$HERE/cost/bench.erl" || exit 1
mkdir -p "$W/src/HotLoop"
cat > "$W/src/HotLoop/HotLoop.bs" <<'X'
module HotLoop

public int Sum(int n)
Sum(n) -> Loop(n, 0)

// private, self-recursive: the shape where a per-call guard would be paid per iteration
private int Loop(int n, int acc)
Loop(0, acc) -> acc
Loop(n, acc) -> Loop(n - 1, acc + n)
X
for v in head widen; do mkdir -p "$W/o/$v"; "$W/c/$v/bsc" --src-root "$W/src" -o "$W/o/$v" "$W/src/HotLoop/HotLoop.bs" >/dev/null || exit 1; done
echo "=== emitted Loop/2 per build ==="
for v in head widen; do echo "--- $v"; escript "$HERE/dump.escript" "$W/o/$v/HotLoop.beam" | sed -n '/Loop/,$p' | head -14; echo "code/file/stripped bytes: $(escript "$HERE/cost/size.escript" "$W/o/$v/HotLoop.beam")"; done
echo
echo "=== ns per Sum(1000000) CALL (one call = 1,000,000 iterations), 15 trials, 5 VM pairs, order alternated ==="
for rep in 1 2 3 4 5; do
  if [ $((rep % 2)) = 1 ]; then order="head widen"; else order="widen head"; fi
  for v in $order; do
    printf '%-7s ' $v
    (cd "$W" && erl -noshell -pa "$W/o/$v" -pa "$W" -run bench main HotLoop Sum 1000000 15 1 2>&1 | tail -1 | sed 's/ | baseline.*//')
  done
done
echo "(values are ns per Sum(1000000) call; divide by 1e6 for ns/iteration)"
