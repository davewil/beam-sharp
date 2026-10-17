#!/usr/bin/env bash
# Probe 2 - what the BEAM can carry and enforce. Bounds what "enforcement" can mean.
# Run: p2_beam_side.sh BSC_DIR
set -eu
here=$(cd "$(dirname "$0")" && pwd); bsc=$1/bsc; t=$here/tree
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
for m in Billing/Ledger Billing Reports; do $bsc --src-root $t -o $out $t/Shop/$m >/dev/null 2>&1; done
ls $out | grep beam
cat > $out/probe.erl <<'EOF'
-module(probe).
-export([main/0]).
main() ->
    L = 'Shop.Billing.Ledger',
    io:format("2a exports of Ledger: ~p~n", [[E || E <- L:module_info(exports), E =/= {module_info,0}, E =/= {module_info,1}]]),
    io:format("2b attributes of Ledger: ~p~n", [L:module_info(attributes)]),
    io:format("2c Erlang caller, not bsc, calls Ledger:Recompute(40,2) = ~p~n", [L:'Recompute'(40, 2)]),
    io:format("2d same via apply/3 (no static edge for any tool): ~p~n", [apply(L, 'Recompute', [1, 1])]),
    {ok, {_, [{attributes, A}]}} = beam_lib:chunks(code:which(L), [attributes]),
    io:format("2e beam_lib attributes chunk: ~p~n", [A]).
EOF
erlc -o $out $out/probe.erl
erl -noshell -pa $out -eval 'probe:main(), halt().'
echo "== 2f Elixir caller"
elixir -pa $out -e 'IO.inspect(apply(:"Shop.Billing.Ledger", :Recompute, [40, 2]), label: "Elixir calls Ledger")' 2>&1 | tail -1
echo "== 2g an attribute CAN ride in the beam (hand-written module, not bsc) and nothing enforces it"
cat > $out/Carrier.erl <<'EOF'
-module('Carrier').
-export(['Recompute'/2]).
-bs_visible_to(['Shop.Billing']).
'Recompute'(A, B) -> A + B.
EOF
erlc -o $out $out/Carrier.erl
erl -noshell -pa $out -eval 'io:format("attrs=~p~ncalled from shell (not Shop.Billing) = ~p~n",['"'"'Carrier'"'"':module_info(attributes), '"'"'Carrier'"'"':'"'"'Recompute'"'"'(1,2)]), halt().'
