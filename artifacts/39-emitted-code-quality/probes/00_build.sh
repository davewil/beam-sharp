#!/usr/bin/env bash
# Build the four Day01 implementations with OTP 28 into work/ebin (Elixir: see notes).
set -e; . "$(dirname "$0")/env.sh"
B=$REPO/aoc/bench; OUT=$W/ebin; rm -rf $OUT; mkdir -p $OUT
erl -noshell -eval 'io:format("OTP ~s erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
erlc -o $OUT $B/bench_erl.erl
# the repo's gleam.toml depends on gleam_stdlib (hex fetch fails offline); the source uses only the prelude, so build a dependency-free copy
rm -rf $W/gleam && mkdir -p $W/gleam && cp -r $B/gleam/src $W/gleam/ && printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > $W/gleam/gleam.toml
(cd $W/gleam && /tmp/tc/gleam build 2>&1 | tail -2)
cp $W/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam $OUT/
$BSC -o $OUT $B/Day01
erlc -o $OUT $B/bench.erl
# Elixir 1.14 only runs on OTP25. Compile there with debug_info, then recompile its abstract forms with OTP 28.
mkdir -p $W/ex25 && PATH=/usr/bin:$PATH elixirc --erl "+debug_info" -o $W/ex25 $B/bench_ex.ex >/dev/null 2>&1 || PATH=/usr/bin:$PATH elixirc -o $W/ex25 $B/bench_ex.ex
ls $W/ex25
ls $OUT
