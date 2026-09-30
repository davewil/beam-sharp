#!/usr/bin/env bash
# Runs every probe and rewrites its .out.  Run setup.sh first.  Probes p03 and p05 print machine-dependent numbers.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
ALL="/usr/lib/elixir/lib:/tmp/mixdeps52b/consumer/_build/dev/lib:/tmp/fakelibs52"
env -u ERL_LIBS escript p01_code_path.erl > p01_code_path.out 2>&1
ERL_LIBS=/usr/lib/elixir/lib escript p01_code_path.erl >> p01_code_path.out 2>&1
./p02_baseline.sh > p02_baseline.out 2>&1
escript p03_census.escript > p03_census.out 2>&1
ERL_LIBS=/usr/lib/elixir/lib escript p03_census.escript > p03_census_with_elixir_libs.out 2>&1
ERL_LIBS=$ALL escript p04_module_to_app.escript > p04_module_to_app.out 2>&1
( escript p05_which_cost.escript; echo; echo "=== with 200 extra app dirs + elixir on ERL_LIBS"; ERL_LIBS=/usr/lib/elixir/lib:/tmp/manylibs52 escript p05_which_cost.escript ) > p05_which_cost.out 2>&1
./p06_run.sh > p06_prototype_check.out 2>&1
./p06a_undeclared_call.sh > p06a_undeclared_call.out 2>&1
./p07_elixir_undeclared.sh > p07_elixir_undeclared.out 2>&1
./p07b_mix_undeclared_dep.sh > p07b_mix_undeclared_dep.out 2>&1
./p08_erlang.sh > p08_erlang.out 2>&1; rm -f neighbours/erl/erl_crash.dump
./p09_gleam.sh > p09_gleam.out 2>&1; rm -rf -- "$HERE/neighbours/gleam_ext/build" "$HERE/neighbours/gleam_imp/build"
./p10_elm.sh > p10_elm.out 2>&1
ERL_LIBS=/usr/lib/elixir/lib:/tmp/mixdeps52b/consumer/_build/dev/lib escript p11_app_module_name_collision.escript > p11_app_module_name_collision.out 2>&1
./p12_grammar_conflicts.sh > p12_grammar_conflicts.out 2>&1
./p13_present_is_not_started.sh > p13_present_is_not_started.out 2>&1
escript p14_beam_attribute_cost.escript > p14_beam_attribute_cost.out 2>&1
./p15_transitive_closure.sh > p15_transitive_closure.out 2>&1
./p16_api_is_environment_free.sh > p16_api_is_environment_free.out 2>&1
./p17_exemplars_with_absent_modules.sh > p17_exemplars_with_absent_modules.out 2>&1
elixir p18_elixir_mix_install_doc.exs > p18_elixir_mix_install_doc.out 2>&1
echo "done: $(ls *.out | wc -l) outputs"
