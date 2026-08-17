#!/usr/bin/env bash
#
# Builds the four Day 1 implementations into one ebin so `bench.erl` can time
# them on the same VM.
#
# REPO-RELATIVE SINCE F15, AND IT HAD TO BE. Every path in here used to be
# absolute: the sources pointed into a job directory that no longer exists
# (`.claude/jobs/c14bc432/tmp/bench`) and the compiler into
# `.claude/worktrees/f7-switch`, a worktree deleted when F7 landed. So this
# script had been dead for as long as the worktree has, and nothing said —
# which is the same failure the features README already records against this
# benchmark once, when the `;` terminator was dropped and the recorded numbers
# became un-re-measurable. No gate reaches `aoc/bench/`, so a script here stays
# broken until somebody runs it.
#
# F15 also moved its beam-sharp input: a module is a directory now, and
# `bench_bs.bs` sits in `Day01/` because it declares `module Day01`.
set -e

B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(cd "$B/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/beam-sharp-bench/day01"

BSC="$W/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || { echo "no bsc — run 'rebar3 escriptize' in compiler/" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

erlc -o "$OUT" "$B/bench_erl.erl"
elixirc -o "$OUT" "$B/bench_ex.ex" >/dev/null 2>&1
(cd "$B/gleam" && gleam build >/dev/null 2>&1)
cp "$B"/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$OUT/"
"$BSC" -o "$OUT" "$B/Day01"
erlc -o "$OUT" "$B/bench.erl"

ls "$OUT" | sed 's/^/  /'
echo "ebin: $OUT"
