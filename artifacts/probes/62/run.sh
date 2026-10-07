#!/usr/bin/env bash
# Re-run every ticket-62 probe; each writes <probe>.out beside itself.
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$(dirname "$0")"
./01_rerun_62a.sh        > 01_rerun_62a.out 2>&1
./02_gleam_call.sh       > 02_gleam_call.out 2>&1
./03_elixir_workarounds.sh > 03_elixir_workarounds.out 2>&1
./04_gleam_names.sh      > 04_gleam_names.out 2>&1
./05_alias_cost.sh       > 05_alias_cost.out 2>&1
./06_alias_from_elixir.sh > 06_alias_from_elixir.out 2>&1
elixir 07_name_table.exs 2>&1 | grep -v latin1 > 07_name_table.out
echo done; ls *.out
