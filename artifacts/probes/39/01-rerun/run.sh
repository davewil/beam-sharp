#!/usr/bin/env bash
# NOTE: the sandbox cannot reach hex.pm, so the unused gleam_stdlib dependency is dropped from the COPY of gleam.toml (the source imports nothing).
# Re-run the four-language benchmark on THIS machine. Builds from scratch into ./build.
set -e
source "$(dirname "$0")/../common.sh"
cd "$(dirname "$0")"; OUT="$PWD/build"; rm -rf "$OUT"; mkdir -p "$OUT"
erlc -o "$OUT" "$BENCH/bench_erl.erl"
elixirc -o "$OUT" "$BENCH/bench_ex.ex" >/dev/null 2>&1
( rm -rf "$OUT/gleam" && cp -r "$BENCH/gleam" "$OUT/gleam" && cd "$OUT/gleam" && rm -rf build && printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml && gleam build >/dev/null 2>&1 )
cp "$OUT"/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam "$OUT/"
( cd "$REPO" && $BSC -o "$OUT" aoc/bench/Day01 )
erlc -o "$OUT" "$BENCH/bench.erl" bench2.erl
echo "== (a) the repo's own harness, unmodified (25 runs, min/median) x3 invocations"
for i in 1 2 3; do erl -noshell -pa "$OUT" -s bench main "$INPUT"; done
echo; echo "== (b) rotated-order harness, 60 runs each (min / quartiles / IQR)"
for i in 1 2 3; do erl -noshell -pa "$OUT" -eval 'bench2:main(["'"$INPUT"'","60"])'; echo; done
