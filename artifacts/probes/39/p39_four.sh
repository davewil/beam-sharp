#!/usr/bin/env bash
# Ticket 39 §1 headline: the unmodified aoc/bench harness (bench.erl), ROUNDS times, one line per round.
. "$(dirname "$0")/../env.sh"; ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; R=${1:-6}; O=$SCRATCH/bench39
for i in $(seq $R); do ( cd $O && erl -noshell -pa $O -eval 'bench:main(["'$ROOT'/aoc/2025/Day01/input.txt"]).' </dev/null | grep -E '^(Erlang|Elixir|Gleam|beam-sharp)' | awk '{printf "%s %s | ", $1, $3}' ); echo; done
