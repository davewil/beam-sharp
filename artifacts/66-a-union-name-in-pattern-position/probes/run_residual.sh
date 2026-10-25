#!/usr/bin/env bash
# What does the stock residual printer say when a whole alias (C = A | B) is missing? (decision #1)
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/residual"
for d in R1 R2; do echo "=== $d"; sed -n '3,$p' $d/m.bs; echo "--- stock bsc:"; $S/bsc --src-root . $d 2>&1; echo "--- --diagnostics json:"; $S/bsc --diagnostics json --src-root . $d 2>&1 | head -c 900; echo; done
