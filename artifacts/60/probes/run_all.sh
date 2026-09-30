#!/usr/bin/env bash
# Re-runs every probe from a clean shell and rewrites its .out. Needs erl/erlc, elixir, gleam at
# /tmp/tools/gleam, python3. Builds compiler/src into /tmp/bsc-build-60 (no rebar3 installed).
cd "$(dirname "$0")"
./build_bsc.sh /tmp/bsc-build-60
export BSC_EBIN=/tmp/bsc-build-60/ebin
for p in p1_private_helper p2_shared_helper p3_ffi_escape p4_nested_modules p5_option_b_prototype \
         p6_shared_helper_under_option_b p7_option_c_prototype p10_check_cost gleam_internal; do
  ./$p.sh > $p.out 2>&1; echo "$p: rewrote $p.out"
done
elixir p9_elixir_erlang_internal.exs > p9_elixir_erlang_internal.out 2>&1
python3 p8_corpus_census.py > p8_corpus_census.out
