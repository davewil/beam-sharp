#!/usr/bin/env bash
# PROBE 62-05 — sizes the blast radius of ticket 62 candidate 3 ("change B#'s own convention to snake_case functions")
# and the population candidate 2 would alias. Uses the REAL lexer (bs_lexer) over every .bs in the repo:
# a `uident` immediately followed by `(` is a function-name token (definition or call). Heuristic, stated as such.
# Also lists the exported-name population from the 27 compiled example modules (beam export tables), which is exact.
# CONTROL: a 3-line B# file with a known answer is tokenised and counted at the end.
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/ebin" "$W/all"
E=/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/bsc/ebin
erlc -o "$W/ebin" artifacts/probes/62/census.erl
erl -noshell -pa "$W/ebin" -pa "$E" -eval 'census:main([]), halt().'
echo
echo "-- exact: exported names of the 27 compiled example modules (beam export tables)"
for d in $(find compiler/examples -name '*.bs' -not -path '*/exemplars/*' -printf '%h\n' | sort -u); do
  $BSC --src-root compiler/examples -o "$W/all" "$d" >/dev/null 2>&1
done
erl -noshell -eval '
  Fs = filelib:wildcard("'"$W"'/all/*.beam"),
  Ex = lists:append([begin {ok,{M,[{exports,E}]}} = beam_lib:chunks(F,[exports]), [{M,N,A} || {N,A} <- E, N =/= module_info, N =/= (list_to_atom("bs@type_atoms"))] end || F <- Fs]),
  Pas = [X || {_,N,_} = X <- Ex, hd(atom_to_list(N)) >= $A, hd(atom_to_list(N)) =< $Z],
  Low = Ex -- Pas,
  io:format("modules ~p, exported author-visible functions ~p, PascalCase ~p, lowercase (behaviour callbacks lowered by bs_otp) ~p~n", [length(Fs), length(Ex), length(Pas), length(Low)]),
  io:format("distinct PascalCase export names ~p~n", [length(lists:usort([N || {_,N,_} <- Pas]))]),
  io:format("lowercase exports: ~p~n", [lists:usort([{N,A} || {_,N,A} <- Low])]),
  halt().'
echo
echo "-- compiler-known standard operations (bs_check:reserved_table/0): inlined or generated locally, no .beam export, so no ABI surface"
erl -noshell -pa "$E" -eval 'T=bs_check:reserved_table(), io:format("~p operations: ~p~n",[length(T), [list_to_atom(atom_to_list(M)++"."++atom_to_list(F)) || {M,F,_} <- T]]), halt().'
