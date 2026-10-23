#!/usr/bin/env bash
# Probe 59-F: the worst case for widening the int kind test -- a hot PRIVATE
# self-recursive loop. Does the guard run on every iteration, or does the BEAM
# type pass prove it away? head = shipped; widen = PROTOTYPE DELTA (int test on private too).
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
echo "=== ns per ITERATION: Sum(1000000), 15 trials, 5 interleaved VM pairs ==="
for rep in 1 2 3 4 5; do
  for v in head widen; do
    printf '%-7s ' $v
    (cd "$W" && erl -noshell -pa "$W/o/$v" -pa "$W" -run bench main HotLoop Sum 1000000 15 1 2>&1 | tail -1 | sed 's/ | baseline.*//')
  done
done
echo "(bench divides by the 1 outer call, so values are ns per Sum(1000000) call; divide by 1e6 for ns/iteration)"
