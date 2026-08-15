#!/usr/bin/env bash
set -e
F=/Volumes/Personal/Users/davidwilliams/.claude/jobs/c14bc432/tmp/fib
W=/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/f7-switch
OUT=$F/ebin
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$F/gl" && gleam build >/dev/null 2>&1
erlc -o "$OUT" "$F/fib_erl.erl"
elixirc -o "$OUT" "$F/fib_ex.ex" >/dev/null 2>&1
cp "$F"/gl/build/dev/erlang/fib_gleam/ebin/fib_gleam.beam "$OUT/"
"$W/compiler/_build/default/bin/bsc" -o "$OUT" "$W/compiler/examples/fib.bs"
erlc -o "$OUT" "$F/fibbench.erl"
ls "$OUT" | tr '\n' ' '; echo
