#!/usr/bin/env bash
# Day01 (bs) with: default / inline / {inline,100}, against Erlang +inline and Gleam. Shuffled harness, 150 rounds.
R=/home/user/beam-sharp/artifacts/39; B=$R/build; O=$B/i100; rm -rf $O; mkdir -p $O
for v in a:"" b:",inline" c:",{inline,100}"; do n=${v%%:*}; o=${v#*:}
  sed "s/'Day01'/'Day01_$n'/g" $B/day01/Day01.abstr > $O/Day01_$n.abstr
  erl -noshell -eval 'compile:file("'$O'/Day01_'$n'.abstr",[from_abstr,debug_info,{outdir,"'$O'"}'"$o"']),halt().' >/dev/null
done
sed "s/-module(bench_erl)/-module(bench_erli)/" /home/user/beam-sharp/aoc/bench/bench_erl.erl > $O/bench_erli.erl; erlc +inline -o $O $O/bench_erli.erl
erlc -o $O $R/probes/bench2.erl
erl -noshell -pa $O -pa $B/day01 -run bench2 main /home/user/beam-sharp/aoc/2025/Day01/input.txt 150 Day01_a:PartTwo Day01_b:PartTwo Day01_c:PartTwo bench_erli:part_two bench_gleam:part_two
