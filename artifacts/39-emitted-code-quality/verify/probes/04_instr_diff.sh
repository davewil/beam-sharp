#!/usr/bin/env bash
# Claim (§1): bsc and Erlang emit identical instructions. Normalise names/labels/lines and diff per function; also whole-module.
. "$(dirname "$0")/env.sh"
norm() { # $1 = dis file; map Capitalised bsc names to erlang's, strip labels/line/func_info
  sed -E "s/'Day01'/bench_erl/g; s/'Wrap'/wrap/g; s/'Hit'/hit/g; s/'Spin'/spin/g; s/'Sign'/sign/g; s/'Size'/size_/g; s/'Clicks'/clicks/g; s/'PartTwo'/part_two/g" $1 \
   | grep -vE '^\s*\{(line|label|func_info)' | grep -vE '^MODULE' | sed -E 's/\{f,[0-9]+\}/{f,L}/g; s/\{(call|call_last|call_only),([0-9]+),\{bench_erl,([a-z_]+),/\{\1,\2,{bench_erl,\3,/'; }
norm $W/bench_erl.dis > $W/n_erl.txt; norm $W/Day01.dis > $W/n_bs.txt
echo "== whole-module normalised diff erl vs bsc (empty = identical) =="; diff $W/n_erl.txt $W/n_bs.txt && echo IDENTICAL-ignoring-order?no
echo "== per-function instr counts =="
for m in bench_erl Day01; do echo $m; grep -E '^--- ' $W/$m.dis; done
