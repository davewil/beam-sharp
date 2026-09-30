#!/usr/bin/env bash
# Rebuild the four Day01 implementations on THIS machine's OTP 25 and run the repo's own harness.
set -e
R=/home/user/beam-sharp; B=$R/artifacts/39/build; O=$B/day01
rm -rf $O; mkdir -p $O
erlc -o $O $R/aoc/bench/bench_erl.erl
elixirc -o $O $R/aoc/bench/bench_ex.ex >/dev/null 2>&1
cp $B/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam $O/
$R/artifacts/39/probes/bsc.sh -o $O $R/aoc/bench/Day01
erlc -o $O $R/aoc/bench/bench.erl
erl -noshell -pa $O -s bench main $R/aoc/2025/Day01/input.txt
