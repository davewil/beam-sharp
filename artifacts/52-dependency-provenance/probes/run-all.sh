#!/usr/bin/env bash
# Runs every probe and regenerates every .out. ~5 minutes (dialyzer PLT, 25-VM cold loops, 20-run CLI timings).
H="$(cd "$(dirname "$0")" && pwd)"; cd "$H"
"$H/fixtures/build-fixtures.sh" >/dev/null
"$H/../prototype/build.sh" >/dev/null
for p in p1_undef_only_at_call_site p2_presence p2b_modes_and_transitive p3a_elixir_mix p3b_erlang p3c_gleam p3d_elm p4_derivable p5_prototype m1_check_cost m2_beam_size m3_pipeline_cost m4_cli_wall; do
  echo ">> $p"; "$H/$p.sh" > "$H/$p.out" 2>&1
done
rm -f "$H"/erl_crash.dump
