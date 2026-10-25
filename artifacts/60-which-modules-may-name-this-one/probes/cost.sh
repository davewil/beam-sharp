#!/usr/bin/env bash
# P10: wall time of a whole-tree compile with the HEAD compiler vs the patched one (extra lookup at every `using`).
P=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$P/beam/bin:$PATH LANG=C.UTF-8
N=${N:-150}; K=${K:-8}
D=$P/60/gen; rm -rf $D; mkdir -p $D/plain $D/within
python3 "$(dirname "$0")/gen_tree.py" $N $K 0 $D/plain
python3 "$(dirname "$0")/gen_tree.py" $N $K 1 $D/within
echo "modules=$N usings/module<=$K  total using edges: $(grep -rh '^using ' $D/plain | wc -l)"
erlc -o $P/60 "$(dirname "$0")/cost_driver.erl"
run() { erl -noshell -pa $1 -pa $P/60 -run cost_driver main "$2" "$N" "$D/out" "$3" -s init stop; }
mkdir -p $D/out
run $P/bsc-build/ebin $D/plain   "HEAD compiler, no within"
run $P/60/proto/ebin  $D/plain   "patched, check runs, no rules"
run $P/60/proto/ebin  $D/within  "patched, every module 'within Gen'"
run $P/bsc-build/ebin $D/plain   "HEAD compiler again (drift check)"
