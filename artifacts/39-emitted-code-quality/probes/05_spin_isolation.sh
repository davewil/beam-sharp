#!/usr/bin/env bash
# §3.1: is the gap in Spin? Feed a ONE-element rotation list [673364] so Clicks does one Spin of 673,364 iterations
# (Sign/Size/Clicks cost ~nothing). Compare with the full 4,732-rotation input (same 673,364 iterations).
. "$(dirname "$0")/env.sh"
echo 673364 | sed 's/^/R/' > $W/one_rotation.txt
echo "== Spin only: one rotation of 673,364 clicks (answer differs from 6770 by design; same across impls is what matters) =="
erl -noshell -pa $W/ebin -eval 'bench2:main(["'$W'/one_rotation.txt","200","Erlang:bench_erl:part_two","Elixir(re28):Elixir.BenchEx:part_two","Gleam:bench_gleam:part_two","beam-sharp:Day01:PartTwo"])'
echo; echo "== full fold again for contrast =="
erl -noshell -pa $W/ebin -eval 'bench2:main(["'$INPUT'","200","Erlang:bench_erl:part_two","Elixir(re28):Elixir.BenchEx:part_two","Gleam:bench_gleam:part_two","beam-sharp:Day01:PartTwo"])'
