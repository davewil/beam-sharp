#!/usr/bin/env bash
#
# The fib benchmark's four implementations, into one ebin for `fibbench.erl`.
#
# REPO-RELATIVE SINCE F15 — see the note in `../build.sh`. Same two dead
# absolute paths (a removed job directory and the `f7-switch` worktree), and
# this one additionally named `compiler/examples/fib.bs`, which F15 moved to
# `compiler/examples/Fib/` when a module became a directory.
set -e

F="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(cd "$F/../../.." && pwd)"
OUT="${TMPDIR:-/tmp}/beam-sharp-bench/fib"

BSC="$W/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || { echo "no bsc — run 'rebar3 escriptize' in compiler/" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

(cd "$F/gleam" && gleam build >/dev/null 2>&1)
erlc -o "$OUT" "$F/fib_erl.erl"
elixirc -o "$OUT" "$F/fib_ex.ex" >/dev/null 2>&1
cp "$F"/gleam/build/dev/erlang/fib_gleam/ebin/fib_gleam.beam "$OUT/"
"$BSC" -o "$OUT" "$W/compiler/examples/Fib"
erlc -o "$OUT" "$F/fibbench.erl"

ls "$OUT" | tr '\n' ' '; echo
echo "ebin: $OUT"
