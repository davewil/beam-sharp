#!/usr/bin/env bash
# Re-runs every ticket-59 probe and writes raw output to out/NN-*.txt (overwritten). First run builds three patched bsc copies (~1 min each).
H="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$H/out"
for p in 00-toolchain 01-as-built 02-scope-variants 03-cost 04-single-caller-elision 05-runtime-cost 06-neighbour-elixir 07-neighbour-gleam 08-neighbour-elm 09-tag-cost-vs-fields 10-deep-door-cost 11-hot-private-loop; do
  echo "== $p"; "$H/$p.sh" > "$H/out/$p.txt" 2>&1; echo "exit $?"
done
