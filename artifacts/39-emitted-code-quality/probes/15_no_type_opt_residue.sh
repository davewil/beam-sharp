#!/usr/bin/env bash
# Follow-up to 06: with +no_type_opt bsc was ~3% slower than hand-written Erlang with the same switch.
# Hypothesis: bsc's FFI result guard `case rem(..) of R when is_integer(R)` is only elided BECAUSE the analyser proves it.
# Check (a) the instructions that remain, (b) re-time 3x.
. "$(dirname "$0")/env.sh"; V=$W/variants   # built by 06
echo "== Wrap/1 instructions, no_type_opt: erlang vs bsc =="
sed -n '/--- wrap\/1/,/^--- /p' $V/e_no_type_opt.dis | grep -vE "^\s*\{(line|label|func_info)" | head -12
sed -n "/--- 'Wrap'\/1/,/^--- /p" $V/b_no_type_opt.dis | grep -vE "^\s*\{(line|label|func_info)" | head -16
echo "is_integer tests in whole module: erl=$(grep -c is_integer $V/e_no_type_opt.dis) bsc=$(grep -c is_integer $V/b_no_type_opt.dis) (default-opt bsc: $(grep -c is_integer $V/b_default.dis))"
for i in 1 2 3; do erl -noshell -pa $V -pa $W/ebin -eval 'bench2:main(["'$INPUT'","80","e_default:e_default:part_two","e_no_type_opt:e_no_type_opt:part_two","b_default:b_default:PartTwo","b_no_type_opt:b_no_type_opt:PartTwo"])' | tail -5; echo; done
