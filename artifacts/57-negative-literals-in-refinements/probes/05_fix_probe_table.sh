#!/usr/bin/env bash
# Run ticket table + fold-extent table + guard table against each PROTOTYPE copy.
# PROTO=<dir containing base|grammar|checker_min|checker_wide>
here=$(cd "$(dirname "$0")" && pwd)
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/4180a786-23e5-53e3-b71e-94fb1d89eea9/scratchpad/proto}
for v in base grammar checker_min checker_wide checker_full refine_only; do
  echo "################ $v"
  export BSC=$PROTO/$v/compiler/_build/default/bin/bsc
  echo "--- 01 ticket table";  bash $here/01_ticket_table.sh 2>&1 | grep -E '^[A-Za-z_0-9]+ +(accepted|refused)'
  echo "--- 04 fold extent";   bash $here/04_fold_extent_table.sh 2>&1
  echo "--- 03 guard vs pattern"; bash $here/03_guard_vs_pattern.sh 2>&1 | grep -E '^[A-Za-z_0-9]+ +(accepted|refused)|^    \| :'
done
