#!/usr/bin/env bash
# Prototype 2 (generalised: any named type, membership emitted by the existing F42 type_test/3 guard builder).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")/proto2_cases"
for d in G*; do
  echo "=================== $d"; sed -n '3,$p' $d/m.bs
  echo "--- prototype 2:"; $S/66/bsc_proto2 --src-root . $d 2>&1 | head -8 | cut -c1-300
done
r(){ printf '%-3s %-34s => ' "$1" "$2"; $S/66/bsc_proto2 --src-root . $1 H "$2" 2>&1 | head -2 | tr '\n' ' ' | cut -c1-200; echo; }
echo "=================== values"
r G1 "{ Kind = :'G1.A', Id = 1 }"; r G1 ":none"; r G1 ":other"; r G1 "5"; r G1 "{ Kind = :'G1.A' }"
r G2 "5"; r G2 "2.5"; r G2 ":none"
r G5 "3"; r G5 "-3"
echo "=================== G3 soundness control: list<int> by head-only test (this is why 84 refuses list<int>)"
r G3 "[1, 2]"; r G3 "[1, :x]"; r G3 "[:x, 1]"
