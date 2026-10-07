#!/usr/bin/env bash
# Does a negative-bounded refinement behave at the exported boundary (F37) under variant A? (BSC=... to choose)
BSC=${BSC:-$(cd "$(dirname "$0")" && pwd)/work/A/_build/default/bin/bsc}
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"; mkdir D
cat > D/d.bs <<'BS'
module D

type Delta = int where value >= -100 and value <= 100

public int D(Delta x)

D(x) -> x + 1
BS
for a in 0 -100 100 -101 101; do printf 'arg %-5s: ' "$a"; "$BSC" D "$a" 2>&1 | head -2 | paste -sd' '; done
echo "--- emitted guard:"; grep -n "integer" D/*.abstr D.abstr 2>/dev/null | head -8
