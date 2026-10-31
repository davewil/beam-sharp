#!/usr/bin/env bash
# Re-runs every probe and rewrites probes/*.out. Needs erl/erlc (OTP 25), elixir 1.14, python3 (p5 median only).
# Usage: bash run_all.sh [/path/to/beam-sharp/compiler]     Exit status = number of failed probes.
cd "$(dirname "$0")"; C=${1:-/home/user/beam-sharp/compiler}; bad=0
mkdir -p ebin && erlc -o ebin src/Shop.erl || exit 99
run() { local n=$1; shift; "$@" > "$n.out" 2>&1; local rc=$?; echo "$n rc=$rc"; [ $rc -eq 0 ] || bad=$((bad+1)); }
run p1_elixir_call_syntax        elixir p1_elixir_call_syntax.exs ebin
run p2_elixir_compiled_and_format elixir p2_elixir_compiled_and_format.exs ebin ex/caller.ex
run p2b_field_access             elixir p2b_field_access.exs
run p3_derivation_census         escript p3_derivation_census.escript "$C"
run p4_alias_collisions          bash p4_alias_collisions.sh
run p5_measure                   bash p5_run.sh
run p6_dialyzer_alias_spec       bash p6_dialyzer_alias_spec.sh
erlc p7_runtime_stack.erl && run p7_runtime_stack erl -noshell -pa . -eval 'p7_runtime_stack:main(), halt().'
run p8_ecosystem_census          escript p8_ecosystem_census.escript
rm -f *.beam
exit $bad
