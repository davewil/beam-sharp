#!/usr/bin/env bash
# 04 — the same programs under each option's compiler.  Prints one result per scenario per variant.
#   v0 today   v1 tag test exported-only   v2 kind test on private too   v3 = v1+v2   v4 = both tests on exported-or-escaping
HERE0="$(cd "$(dirname "$0")" && pwd)"
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
for v in v0 v1 v2 v3 v4; do
  echo "######## $v"
  W=$(mktemp -d)
  BSC=$SCRATCH/var/$v/bsc WORK=$W "$HERE0/02_escape.sh" 2>&1 | sed -n '/^TotalOf\|^Twice\|^Narrow/p'
  BSC=$SCRATCH/var/$v/bsc WORK=$W "$HERE0/03_reach.sh" 2>&1 | sed -n '/^SumTotals(\[Good\|^SumInts/p'
  BSC=$SCRATCH/var/$v/bsc WORK=$W "$HERE0/02b_foreign_callback.sh" 2>&1 | sed -n "/^Run(/p"
done
