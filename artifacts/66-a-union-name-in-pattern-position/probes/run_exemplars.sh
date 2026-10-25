#!/usr/bin/env bash
# Re-run the ticket's five exemplars against bsc at HEAD. Usage: run_exemplars.sh
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/ex"
for i in 1 2 3 4 5; do echo "=== E$i"; cat E$i/e$i.bs | sed -n '8,$p'; echo "--- bsc:"; $S/bsc --src-root . E$i 2>&1; echo "rc=$?"; done
