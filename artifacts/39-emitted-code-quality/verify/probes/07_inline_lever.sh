#!/usr/bin/env bash
# What actually explains Gleam being fastest here? bench_gleam.erl (Gleam's own output) carries -compile([...,inline]).
# Test: give Erlang and bsc's .abstr the same switch (erlc +inline) and see if they match Gleam. No source change in bsc.
. "$(dirname "$0")/env.sh"
V=$W/variants2; rm -rf $V; mkdir -p $V; B=$REPO/aoc/bench
grep -n "compile" $W/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl | head -3
mk_erl() { n=$1; shift; sed "s/-module(bench_erl)/-module($n)/" $B/bench_erl.erl > $V/$n.erl; erlc "$@" -o $V $V/$n.erl; }
mk_bs()  { n=$1; shift; sed "s/'Day01'/'$n'/" $W/ebin/Day01.abstr > $V/$n.abstr; erlc +from_abstr "$@" -o $V $V/$n.abstr; }
mk_erl e_default; mk_erl e_inline +inline; mk_bs b_default; mk_bs b_inline +inline
mk_bs b_inline_listed "+{inline,[{'Wrap',1},{'Hit',1}]}"
cp $W/ebin/bench_gleam.beam $V/
for n in e_default e_inline b_default b_inline b_inline_listed; do
  erl -noshell -pa $W -eval 'dis:main(["'$V'/'$n'.beam"])' > $V/$n.dis
  echo "$n: bytes=$(stat -c%s $V/$n.beam) spin: $(grep -E '^--- .?[sS]pin' $V/$n.dis) calls_in_spin=$(sed -n "/--- .\?[sS]pin/,/^--- /p" $V/$n.dis | grep -c '{call')"
done
echo; echo "== timing (min is the stable column; box is shared & loaded) 100 rounds x3 =="
for i in 1 2 3; do
erl -noshell -pa $V -pa $W/ebin -eval 'bench2:main(["'$INPUT'","100","e_default:e_default:part_two","e_inline:e_inline:part_two","b_default:b_default:PartTwo","b_inline:b_inline:PartTwo","b_inline_listed:b_inline_listed:PartTwo","gleam:bench_gleam:part_two"])' | tail -7; echo; done
