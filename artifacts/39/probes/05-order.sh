#!/usr/bin/env bash
# Does position in the original sequential harness matter? Same protocol, both orders, 3 repeats each.
R=/home/user/beam-sharp; O=$R/artifacts/39/build/day01
erlc -o $O $R/artifacts/39/probes/bench_seq.erl
E=bench_erl:part_two; B="Day01:PartTwo"; X="Elixir.BenchEx:part_two"; G=bench_gleam:part_two
for rep in 1 2 3; do
  echo "--- order: bs FIRST (bs, erl, elixir, gleam)"; erl -noshell -pa $O -run bench_seq main $R/aoc/2025/Day01/input.txt $B $E $X $G
  echo "--- order: bs LAST  (erl, elixir, gleam, bs)"; erl -noshell -pa $O -run bench_seq main $R/aoc/2025/Day01/input.txt $E $X $G $B
  echo "--- order: bs, bs, bs (same impl three times)"; erl -noshell -pa $O -run bench_seq main $R/aoc/2025/Day01/input.txt $B $B $B
done
