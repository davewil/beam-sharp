#!/usr/bin/env bash
#
# Probe copy of aoc/bench/build.sh for ticket 39. Identical logic, except the
# Gleam module is built from a network-free scratch copy (artifacts/39-probes/
# gleam-scratch — same source, no gleam_stdlib dependency, which the bench
# module never actually imports) because repo.hex.pm is not reachable from
# this sandbox. Does not touch aoc/bench/ or wayfinder/.
set -e

W="/home/user/beam-sharp"
B="$W/aoc/bench"
GSCRATCH="$W/artifacts/39-probes/gleam-scratch"
OUT="/tmp/beam-sharp-bench-39/day01"

BSC="$W/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || { echo "no bsc — run 'rebar3 escriptize' in compiler/" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

erlc -o "$OUT" "$B/bench_erl.erl"
elixirc -o "$OUT" "$B/bench_ex.ex" >/dev/null 2>&1
(cd "$GSCRATCH" && gleam build >/dev/null 2>&1)
cp "$GSCRATCH"/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$OUT/"
"$BSC" -o "$OUT" "$B/Day01"
erlc -o "$OUT" "$B/bench.erl"

ls "$OUT" | sed 's/^/  /'
echo "ebin: $OUT"
