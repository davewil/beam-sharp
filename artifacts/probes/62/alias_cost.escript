#!/usr/bin/env escript
%% Ticket 62 P4: BEAM cost of emitting a snake_case alias export beside each PascalCase export.
%% Takes the emitted .abstr (the contract: forms on disk), appends one forwarding wrapper per export, recompiles.
%% usage: alias_cost.escript path/to/Mod.abstr
main([Abstr]) ->
    {ok, Forms} = file:consult(Abstr),
    Base = compile_(Forms),
    Exports = [{N, A} || {attribute, _, export, L} <- Forms, {N, A} <- L, N =/= 'bs@type_atoms'],
    Aliased = [{snake(N), A, N} || {N, A} <- Exports],
    Used = sets:from_list([{N, A} || {N, A} <- lists:flatten([L || {attribute,_,export,L} <- Forms])]),
    Wrappers = [wrapper(S, A, N) || {S, A, N} <- Aliased, not sets:is_element({S, A}, Used)],
    ExpAttr = {attribute, 1, export, [{S, A} || {S, A, _} <- Aliased, not sets:is_element({S, A}, Used)]},
    {Pre, Post} = lists:splitwith(fun(F) -> element(1, F) =/= function end, Forms),
    Eof = [F || F = {eof, _} <- Post], Funs = [F || F <- Post, element(1, F) =/= eof],
    Forms2 = Pre ++ [ExpAttr] ++ Funs ++ Wrappers ++ Eof,
    With = compile_(Forms2),
    io:format("exports=~p aliases_added=~p~n", [length(Exports), length(Wrappers)]),
    io:format("beam bytes: before=~p after=~p delta=~p (~.1f B/alias)~n",
              [byte_size(Base), byte_size(With), byte_size(With) - byte_size(Base),
               (byte_size(With) - byte_size(Base)) / max(1, length(Wrappers))]),
    {ok, _, B1} = {ok, x, Base}, {ok, {_, [{"ExpT", E0}]}} = beam_lib:chunks(B1, ["ExpT"]),
    {ok, {_, [{"ExpT", E1}]}} = beam_lib:chunks(With, ["ExpT"]),
    ok = file:write_file(filename:join(os:getenv("OUT","."), "Shop.beam"), With),
    io:format("ExpT chunk bytes: ~p -> ~p~n", [byte_size(E0), byte_size(E1)]).
compile_(Forms) ->
    {ok, _, Bin} = compile:forms(Forms, [from_abstr, binary, return_errors]), Bin.
wrapper(S, A, N) ->
    Vs = [{var, 1, list_to_atom("V" ++ integer_to_list(I))} || I <- lists:seq(1, A)],
    {function, 1, S, A, [{clause, 1, Vs, [], [{call, 1, {atom, 1, N}, Vs}]}]}.
%% Macro.underscore-like: acronym-aware
snake(N) ->
    S = atom_to_list(N),
    list_to_atom(string:lowercase(re:replace(re:replace(S, "([A-Z]+)([A-Z][a-z])", "\\1_\\2", [global, {return, list}]),
                                              "([a-z0-9])([A-Z])", "\\1_\\2", [global, {return, list}]))).
