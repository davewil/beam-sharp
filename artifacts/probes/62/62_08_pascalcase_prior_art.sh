#!/usr/bin/env bash
# PROBE 62-08 — Prior art: do any installed OTP / Elixir modules export a function whose name starts with an
# uppercase letter (the shape B# produces)? Reads the export table (beam_lib) of every .beam under the installed
# erlang/lib and elixir/lib trees. Not about hex packages (blocked). CONTROL: the same scan must find the
# lowercase `lists:reverse/1` (proves the scan reads exports), and must find uppercase names in a beam
# compiled by bsc (Shop:'New'/1) when pointed at it.
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
L=/tmp/claude-0/mm/root/envs/b/lib
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir "$W/b"
$BSC --src-root compiler/examples -o "$W/b" compiler/examples/Shop >/dev/null 2>&1
erl -noshell -eval '
  Scan = fun(Root) ->
     Fs = filelib:wildcard(Root ++ "/**/*.beam"),
     {length(Fs), lists:append([begin
        case beam_lib:chunks(F, [exports]) of
          {ok, {M, [{exports, E}]}} -> [{M, N, A} || {N, A} <- E, is_atom(N), hd(atom_to_list(N)) >= $A, hd(atom_to_list(N)) =< $Z, string:prefix(atom_to_list(N), "MACRO-") =:= nomatch];
          _ -> [] end end || F <- Fs]), Fs}
  end,
  {NO, UO, FO} = Scan("'"$L"'/erlang/lib"),
  {NE, UE, _} = Scan("'"$L"'/elixir/lib"),
  io:format("OTP beams scanned ~p ; uppercase-first exports ~p, modules ~p~n", [NO, length(UO), lists:usort([M || {M,_,_} <- UO])]),
  io:format("Elixir beams scanned ~p ; uppercase-first exports (MACRO- excluded: the macro namespace) ~p, ~p~n", [NE, length(UE), lists:usort([{M,N} || {M,N,_} <- UE])]),
  {ok, {_, [{exports, LE}]}} = beam_lib:chunks(hd([F || F <- FO, filename:basename(F) =:= "lists.beam"]), [exports]),
  io:format("CONTROL lists.beam exports reverse/1: ~p~n", [lists:member({reverse,1}, LE)]),
  {NB, UB, _} = Scan("'"$W"'/b"),
  io:format("CONTROL bsc beam dir scanned ~p ; uppercase-first exports ~p~n", [NB, length(UB)]),
  halt().'
