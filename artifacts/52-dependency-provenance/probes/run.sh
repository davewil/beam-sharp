#!/bin/sh
# Regenerates every .out from scratch. Timing lines in p3/p6 vary run to run; all other lines are deterministic.
cd "$(dirname "$0")"
rm -rf work
sh versions.sh > versions.out 2>&1
./p1_missing_module.sh      > p1_missing_module.out 2>&1
./p1b_xref.sh               > p1b_xref.out 2>&1
./p2_elixir_missing.sh      > p2_elixir_missing.out 2>&1
./p3_run.sh                 > p3_lookup.out 2>&1
./p4_appfiles.sh            > p4_appfiles.out 2>&1
./p4b_mix_beam.sh           > p4b_mix_beam.out 2>&1
./p5_elm.sh                 > p5_elm.out 2>&1
./p6_real_elixir_and_cost.sh > p6_real_elixir_and_cost.out 2>&1
echo done
