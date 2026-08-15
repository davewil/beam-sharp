#!/usr/bin/env bash
set -e
B=/Volumes/Personal/Users/davidwilliams/.claude/jobs/c14bc432/tmp/bench
W=/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/f7-switch
OUT=$B/ebin
rm -rf "$OUT"; mkdir -p "$OUT"

erlc -o "$OUT" "$B/bench_erl.erl"
elixirc -o "$OUT" "$B/bench_ex.ex" >/dev/null 2>&1
cp "$B"/gl/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$OUT/"
"$W/compiler/_build/default/bin/bsc" -o "$OUT" "$B/bs/day01.bs"
erlc -o "$OUT" "$B/bench.erl"

ls "$OUT" | sed 's/^/  /'
