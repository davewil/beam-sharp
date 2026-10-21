#!/usr/bin/env escript
%% corpus.escript EBIN SRCROOT OUTDIR -> "name beam_bytes guard_count" per example module directory
main([Ebin, Root, Out]) ->
    true = code:add_patha(Ebin),
    {ok, Ds} = file:list_dir(Root),
    Rows = [begin
        P = filename:join(Root, D),
        O = filename:join(Out, D), filelib:ensure_dir(O ++ "/x"),
        R = try bsc:file_to_dir(P, O) catch C:E -> {C, E} end,
        case R of
            {ok, _} ->
                Bs = filelib:wildcard(O ++ "/*.beam"),
                Sz = lists:sum([filelib:file_size(B) || B <- Bs]),
                G = lists:sum([guards(B) || B <- Bs]),
                {D, ok, Sz, G};
            _ -> {D, refused, 0, 0}
        end
    end || D <- lists:sort(Ds), filelib:is_dir(filename:join(Root, D))],
    [io:format("~-14s ~-8s ~8w ~6w~n", tuple_to_list(Row)) || Row <- Rows],
    io:format("TOTAL ~w bytes, ~w guards across ~w modules~n",
              [lists:sum([S || {_, ok, S, _} <- Rows]), lists:sum([G || {_, ok, _, G} <- Rows]),
               length([x || {_, ok, _, _} <- Rows])]).
guards(B) ->
    {ok, {_, [{abstract_code, {_, Fs}}]}} = beam_lib:chunks(B, [abstract_code]),
    length([x || {function,_,_,_,Cs} <- Fs, {clause,_,_,Gs,_} <- Cs, Gs =/= []]).
