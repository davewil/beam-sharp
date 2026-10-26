#!/usr/bin/env bash
# Re-runs every probe for ENG-241 from the sources in this directory. Needs erlc, escript, elixir(c).
set -eu
cd "$(dirname "$0")"; rm -rf ebin ex/*.beam; mkdir -p ebin
echo "# OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')"
for f in g_none g_pub g_both g_unknown leaf s_tag0 s_tag1 s_int0 s_int1 e_labels forge bench; do
  erlc +deterministic +no_line_info -o ebin $f.erl
  [ $f = bench ] || erlc +deterministic +no_line_info -S -o ebin $f.erl
done
echo "## P1 sizes";                 escript sizes.escript | tee sizes.out
echo "## P2 elision (local fns)";   { for m in g_pub g_both g_unknown; do echo "-- $m"; sed -n '/function, inner/,/function, [a-z_]*, [0-9], [0-9]*}\.$/p' ebin/$m.S | grep -E "function, inner|is_integer|is_eq_exact|map_get|func_info" ; done; } | tee elision.out
echo "## P3 entry labels";          sed -n '/function, pub/,/function, module_info, 0/p' ebin/e_labels.S | tee labels.out
echo "## P4 bench";                 erl -noshell -pa ebin -eval 'bench:run(),halt().' | tee bench.out
echo "## P5 forged reachability";   escript forge.escript | tee forge.out
echo "## P5b container hole for the int kind"; escript leaf.escript | tee leaf.out
echo "## P6 Elixir";                (cd ex && elixirc order.ex -o .) && elixir ex_forms.exs | tee ex_forms.out && elixir ex_disasm.exs | tee ex_disasm.out
echo "## P7 Elm";                   bash elm-attempt.sh | tee elm.out
