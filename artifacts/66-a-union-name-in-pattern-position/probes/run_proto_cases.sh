#!/usr/bin/env bash
# Run each proto_cases/P* against the STOCK bsc and the PROTOTYPE bsc (copy of sources with the union-name lowering).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/proto_cases"
for d in P*; do
  echo "=================== $d"; sed -n '3,$p' $d/m.bs
  echo "--- stock:";     $S/bsc --src-root . $d 2>&1 | head -12; 
  echo "--- prototype:"; $S/66/bsc_proto --src-root . $d 2>&1 | head -14
done
