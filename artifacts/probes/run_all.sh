#!/bin/sh
# Run every probe, in order, teeing each to results/<ticket>-<probe>.txt next to this file (or $RESULTS).
# Needs: bsc built (compiler/_build/default/bin/bsc, OTP 28), env.sh sourced or TC pointing at the toolchains.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); . "$HERE/env.sh"; R=${RESULTS:-$HERE/results}; mkdir -p "$R"
run() { out="$R/$1.txt"; shift; echo "### $*" > "$out"; ( cd "$HERE" && "$@" ) >> "$out" 2>&1; echo "exit=$?" >> "$out"; printf '%-34s %s\n' "$(basename "$out" .txt)" "$(tail -1 "$out")"; }
run 59-p1 59/p1_emitted_guards.sh
run 59-p2 59/p2_forged_nested.sh
run 59-p3 59/p3_guard_census.sh
run 59-p4 59/p4_guard_cost.escript
run 59-p5 59/p5_elixir_defp_struct_head.sh
run 60-p1 60/p1_gleam_internal.sh
run 60-p2 60/p2_elixir_erlang_advisory.sh
run 60-p3 60/p3_bsc_who_half.sh
run 62-p1 62/p1_elixir_call_syntax.sh
run 62-p2 62/p2_gleam_external_and_casing.sh
run 62-p3 62/p3_alias_derivation_corpus.sh
run 62-p4 62/p4_alias_cost.sh
run 64-p1 64/p1_representation_cost.sh
run 64-p2 64/p2_neighbours_lookup.sh
run 64-p3 64/p3_collapse_matrix.sh
run 64-p4 64/p4_lookup_in_bsharp.sh
run 65-p1 65/p1_bsc_reserved_surface.sh
run 65-p2 65/p2_neighbours_shadowing.sh
run 65-p3 65/p3_elixir_root_clobber.sh
