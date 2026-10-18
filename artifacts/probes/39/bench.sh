#!/bin/bash
# Ticket 39 (ENG-211): re-measure the four-language AoC Day 1 benchmark on this toolchain.
# Deviation: the Gleam copy drops gleam_stdlib from gleam.toml (hex.pm is unreachable here; the source has no imports).
. "$(dirname "$0")/../env.sh"
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
B=$ROOT/aoc/bench
work 39
OUT=$W/out; mkdir -p $OUT
echo "toolchain: OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')  $(elixir --version 2>/dev/null | tail -1)  $(gleam --version)"
echo "JIT: $(erl -noshell -eval 'io:format("~p",[erlang:system_info(emu_flavor)]),halt().')"
erlc -o $OUT $B/bench_erl.erl
elixirc -o $OUT $B/bench_ex.ex >/dev/null 2>&1
cp -r $B/gleam $W/gleam && (cd $W/gleam && rm -rf build manifest.toml && printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml && gleam build >/dev/null 2>&1) && cp $W/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam $OUT/
bsc -o $OUT $B/Day01 2>&1 | head -3
erlc -o $OUT $B/bench.erl
ls $OUT
for i in 1 2 3; do
  echo "--- run $i"
  erl -noshell +pc unicode -pa $OUT -eval 'bench:main(["'$ROOT'/aoc/2025/Day01/input.txt"])' 2>&1 | cut -c1-160 | tail -8
done
echo "OUT=$OUT"
