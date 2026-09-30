#!/usr/bin/env bash
# What compile options did each toolchain give the Erlang compiler, and does each Spin call wrap/hit or inline them?
R=/home/user/beam-sharp/artifacts/39; B=$R/build/day01
erlc -o $B $R/probes/probe12.erl
erl -noshell -pa $B -eval "probe12:main([])"
echo; echo "Gleam's generated Erlang, line 2:"; sed -n 2p $R/build/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.erl
