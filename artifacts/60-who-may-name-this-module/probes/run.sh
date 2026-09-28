#!/bin/sh
# Regenerates every probes/*.out. Run from anywhere.
cd "$(dirname "$0")" || exit 1
{ erl -noshell -eval 'io:format("otp ~s erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
  elixir --version | tail -1; elm --version | sed 's/^/elm /'; echo "gleam: not installed, not probed"; } > versions.out 2>&1
escript erl_caller_restriction.escript > erl_caller_restriction.out 2>&1
[ -f ex_probe.exs ] && elixir ex_probe.exs > ex_probe.out 2>&1
[ -f cost.escript ] && escript cost.escript > cost.out 2>&1
[ -f prefix_rule.escript ] && escript prefix_rule.escript > prefix_rule.out 2>&1
[ -f mix_xref_probe.sh ] && sh mix_xref_probe.sh > mix_xref_probe.out 2>&1
[ -f elm_probe.sh ] && sh elm_probe.sh > elm_probe.out 2>&1
