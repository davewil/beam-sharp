#!/bin/sh
# Re-runs every ticket-60 probe; each writes <dir>/run.out
cd "$(dirname "$0")" || exit 1
for d in bsc gleam go elixir elm erlang proto; do sh $d/run.sh > $d/run.out 2>&1; echo "$d -> $d/run.out"; done
