#!/usr/bin/env bash
# Runs every ticket-52 probe in order. Needs: erl/erlc/escript/elixir on PATH,
# gleam in /tmp/bin (P8), and a built bsc at $BSC (see common.sh).
set -u
cd "$(dirname "$0")"
for p in p1_missing_module.sh p2_otp_introspection.sh p3_compile_time_check.sh p4_attribute_cost.sh \
         p5_neighbours.sh p8_gleam.sh; do
  echo; echo "################ $p"; ./$p 2>&1
done
echo; echo "################ p6_elixir_source_lines.exs"; elixir p6_elixir_source_lines.exs 2>&1 | cut -c1-200
echo; echo "################ p7_version_strings.exs";     elixir p7_version_strings.exs 2>&1
