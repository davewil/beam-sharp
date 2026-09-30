#!/usr/bin/env bash
# Emit the final BEAM assembly (erlc -S equivalent) for the Erlang source and the bsc .abstr, and diff the function bodies.
R=/home/user/beam-sharp; B=$R/artifacts/39/build; O=$B/asm; mkdir -p $O
cp $R/aoc/bench/bench_erl.erl $O/
erlc -S -o $O $O/bench_erl.erl
erl -noshell -eval 'R=compile:file("'$B'/day01/Day01.abstr",[from_abstr,debug_info,'"'S'"',{outdir,"'$O'"}]),io:format("~p~n",[R]),halt().'
ls $O
echo "== Erlang wrap/spin ==";  awk '/^\{function, wrap/,/^\{function, hit/' $O/bench_erl.S | head -60
echo "== B# Wrap ==";  awk "/^\{function, 'Wrap'/,/^\{function, 'Hit'/" $O/Day01.S | head -60
