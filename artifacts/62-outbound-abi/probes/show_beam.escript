#!/usr/bin/env escript
%% usage: show_beam.escript FILE.beam   -> exports, atom table, abstract code (pretty printed)
main([F]) ->
    {ok, {M, Chunks}} = beam_lib:chunks(F, [exports, atoms, abstract_code]),
    io:format("module: ~p~n", [M]),
    {exports, Ex} = lists:keyfind(exports, 1, Chunks),
    io:format("exports: ~p~n", [lists:sort(Ex)]),
    {atoms, As} = lists:keyfind(atoms, 1, Chunks),
    io:format("atoms:   ~p~n", [[A || {_, A} <- As]]),
    case lists:keyfind(abstract_code, 1, Chunks) of
        {abstract_code, {_, Forms}} ->
            io:format("--- abstract code (erl_pp)~n"),
            [io:put_chars(erl_pp:form(Fm)) || Fm <- Forms,
               element(1, Fm) =:= function orelse element(1, Fm) =:= attribute andalso element(3, Fm) =:= type];
        _ -> io:format("(no abstract code)~n")
    end.
