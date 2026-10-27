#!/usr/bin/env bash
# Hypothesis H1: on OTP 25.3 the shimmed-bsc Day01 is ~20% slower than Erlang/Elixir (the ticket's OTP 28 claim).
# Falsified if bsc/Erlang min-time ratio < 1.10. Same harness shape as aoc/bench/bench.erl (answer check,
# min+median of 25 runs), Gleam omitted (unavailable). Run twice to show run-to-run noise.
set -e
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39
B=/home/user/beam-sharp/aoc/bench; O=$W/bench; rm -rf $O; mkdir -p $O
erlc -o $O $B/bench_erl.erl; elixirc -o $O $B/bench_ex.ex >/dev/null 2>&1
erl -noshell -pa $W/ebin -eval 'bsc:main(["-o","'$O'","'$B'/Day01"]),halt().'
erlc -o $O "$(dirname "$0")/bench4.erl"
for i in 1 2 3; do erl -noshell -pa $O -s bench4 main /home/user/beam-sharp/aoc/2025/Day01/input.txt; done
