#!/usr/bin/env bash
# Ticket 15 section 1 collapse refusal x record-union aliases. Stock bsc, then the union-name prototype on Q-cases that use `C c`.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/collapse_cases"
for d in Q*; do echo "=== $d"; sed -n '3,$p' $d/m.bs; echo "--- stock rc/out:"; $S/bsc -o /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/66/q_out --src-root . $d 2>&1 | head -10; echo "rc=${PIPESTATUS[0]}"; done
