#!/usr/bin/env bash
# Re-runs every ENG-239 probe from scratch and diffs each against its recorded .out.
# Timings (p5) are compared by shape only: the three lines are printed, not diffed.
# Needs: erl/escript (OTP 25 here), elixir, elm. bsc is NOT run: it cannot build on OTP 25.
set -u
cd "$(dirname "$0")"
rc=0
chk () { # name command...
  n=$1; shift
  "$@" > "/tmp/eng239.$n.new" 2>&1
  if diff -q "$n.out" "/tmp/eng239.$n.new" >/dev/null; then echo "same   $n"; else echo "DIFFER $n"; diff "$n.out" "/tmp/eng239.$n.new" | head -6; rc=1; fi
}
chk p1 ./p1_erlang_forms.escript
chk p2 ./p2_fold_stage.sh
chk p3 elixir p3_elixir.exs
chk p4 ./p4_elm.sh
chk p6 ./p6_erlang_pattern_arith.escript
chk p7 elixir p7_elixir_positions.exs
echo "--- p5 (timing; expect fold_us well under parse_us, 'after=0')"; ./p5_fold_cost.escript
exit $rc
