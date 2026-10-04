#!/usr/bin/env bash
# Parse/check cost on a generated 1000-refinement module, per variant. Reductions are the load-independent metric
# (the machine is shared; wall ms are shown but NOT comparable). Pos = non-negative bounds (accepted today),
# Neg = signed bounds (refused today, so `check` on base reports errors/raises: cost of a refusal, not of an answer).
N=${N:-1000}; REPS=${REPS:-9}
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/4180a786-23e5-53e3-b71e-94fb1d89eea9/scratchpad/proto}
here=$(cd "$(dirname "$0")" && pwd)
export PATH=/opt/otp28/bin:$PATH
d=$(mktemp -d); trap 'rm -rf $d' EXIT
{ echo "module Pos"; for i in $(seq 1 $N); do echo "type T$i = int where value >= 0 and value <= $i"; done; echo "public int Id(T1 b)"; echo "Id(b) -> b"; } > $d/pos.bs
{ echo "module Neg"; for i in $(seq 1 $N); do echo "type T$i = int where value >= -$i and value <= $i"; done; echo "public int Id(T1 b)"; echo "Id(b) -> b"; } > $d/neg.bs
# Neg_one_by_one: base cannot check a file with ANY refused refinement in bulk, so also a file of 1000 negative-LITERAL expressions
{ echo "module Lit"; echo; echo "public int F(int x)"; for i in $(seq 1 $N); do echo "F(x) when x == $i -> -$i"; done; echo "F(x) -> -1"; } > $d/lit.bs
for f in pos neg lit; do
  echo "=== $f.bs ($(wc -l < $d/$f.bs) lines)"
  for v in base grammar checker_full; do
    printf '%-13s ' $v; escript $here/measure.escript $PROTO/$v/compiler/_build/default/lib/bsc/ebin $d/$f.bs $REPS
  done
done
