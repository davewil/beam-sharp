#!/usr/bin/env bash
# Claim (ticket header): beam-sharp ~1.20x slower than Erlang/Elixir/Gleam, same answer. Re-run on this machine.
. "$(dirname "$0")/env.sh"
echo "== repo harness unchanged (25 runs, sequential per impl), x3 =="
for i in 1 2 3; do erl -noshell -pa $W/ebin -s bench main $INPUT; echo; done
echo "== interleaved harness, 300 rounds, x3 =="
for i in 1 2 3; do
erl -noshell -pa $W/ebin -eval 'bench2:main(["'$INPUT'","300","Erlang:bench_erl:part_two","Elixir(re28):Elixir.BenchEx:part_two","Gleam:bench_gleam:part_two","beam-sharp:Day01:PartTwo"])' ; echo; done
