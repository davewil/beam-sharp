#!/usr/bin/env bash
# Neighbour-language probes. Prints PASS/FAIL/RECORD; exit 1 on any FAIL.
here=$(cd "$(dirname "$0")" && pwd)
out=$( { elixir "$here/elixir.exs"; escript "$here/erlang.escript"; "$here/gleam.sh"; "$here/elm.sh"; } 2>&1 )
printf '%s\n' "$out"
printf '%s\n' "$out" | grep -q '^FAIL ' && exit 1
exit 0
