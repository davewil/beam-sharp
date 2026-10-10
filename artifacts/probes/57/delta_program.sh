#!/usr/bin/env bash
# The brief's program: Sign over Delta (-100..100), no catch-all, then run it at and beyond the bounds.
BSC=${1:?bsc}
W=$(mktemp -d); mkdir $W/P
cat > $W/P/p.bs <<'EOS'
module P

type Delta = int where value >= -100 and value <= 100

public atom Sign(Delta d)

Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos
EOS
cd $W; "$BSC" -o out P; echo "compile rc=$?"
for a in -100 -1 0 7 100 101 -101; do printf 'Sign(%s) = ' $a; "$BSC" -o out P Sign $a 2>&1 | head -2; done
