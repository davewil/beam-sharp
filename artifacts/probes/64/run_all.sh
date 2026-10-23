#!/usr/bin/env bash
# Runs every ticket-64 probe in order. Usage: source <scratchpad>/env.sh; ./run_all.sh | tee output.txt
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
for p in 64a_refusal_matrix.sh 64b_tagged_lookup.sh 64c_tagged_sibling.sh 64d_representation_cost.sh \
         64e_gleam_absent_vs_sentinel.sh 64f_erlang_elixir_absent.sh 64g_valve_over_tagged.sh \
         64h_sentinel_outside_term.sh 64i_instantiation_is_silent.sh 64j_compile_time.sh 64k_elm_attempt.sh; do
  printf '\n################ %s ################\n' "$p"
  ./"$p" 2>&1
done
