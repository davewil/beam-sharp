#!/usr/bin/env bash
# Ticket 57: accepting `value >= -5` is not enough; the refinement must also MEAN >= -5 at the exported boundary
# (ticket 18/58 guard). Runs a function over a refinement with -6 / -5 / 0 / 5 / 6 against a patched build.
# Usage: BSC=<patched bsc> bash p4_refinement_means_what_it_says.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?set BSC to a patched bsc}
d=$(mktemp -d); mkdir -p $d/Delta
cat > $d/Delta/a.bs <<'EOF'
module Delta
type Delta = int where value >= -5 and value <= 5
public int Twice(Delta d)
Twice(d) -> d * 2
EOF
for a in -6 -5 0 5 6; do printf 'Twice(%s) -> ' "$a"; "$BSC" $d/Delta/a.bs Twice "$a" 2>&1 | head -2 | tr '\n' ' '; echo; done
