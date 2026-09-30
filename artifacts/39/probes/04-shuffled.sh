#!/usr/bin/env bash
# Shuffled, fresh-process, 150-round comparison of the four (after 01-rebench.sh has built build/day01).
R=/home/user/beam-sharp; O=$R/artifacts/39/build/day01
erlc -o $O $R/artifacts/39/probes/bench2.erl
erl -noshell -pa $O -run bench2 main $R/aoc/2025/Day01/input.txt 150 bench_erl:part_two "Elixir.BenchEx:part_two" bench_gleam:part_two "Day01:PartTwo"
