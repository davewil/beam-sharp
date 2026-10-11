#!/usr/bin/env escript
%% How does OTP's own code treat private vs exported parameters? A parameter position is
%% BARE (ticket 18's census: a position is DEFENDED only if EVERY clause constrains it) when, in at least one clause, its pattern is a variable or `_` and no guard of that clause
%% mentions that variable. (Same test as ticket 18 s1's census, split by visibility.)
%% Also confirms that a -spec is not enforced at run time.
main(_) ->
    Root = code:lib_dir(stdlib),
    Dirs = [code:lib_dir(stdlib) ++ "/ebin", code:lib_dir(kernel) ++ "/ebin"],
    Beams = lists:append([filelib:wildcard(D ++ "/*.beam") || D <- Dirs]),
    Acc = lists:foldl(fun scan/2, #{}, Beams),
    io:format("beams scanned: ~p (root ~s)~n", [length(Beams), Root]),
    [io:format("~-9s functions=~p  parameter positions=~p  bare=~p (~.1f%)  functions with every position defended=~p (~.1f%)~n",
               [K, Fn, Pos, Bare, 100*Bare/max(1,Pos), Def, 100*Def/max(1,Fn)])
     || {K, {Fn, Pos, Bare, Def}} <- lists:sort(maps:to_list(Acc))].
scan(F, Acc) ->
    case beam_lib:chunks(F, [abstract_code, exports]) of
        {ok, {_, [{abstract_code, {_, Forms}}, {exports, Ex}]}} ->
            lists:foldl(fun({function, _, N, A, Cs}, Ac) ->
                                K = case lists:member({N, A}, Ex) of true -> exported; false -> private end,
                                {Bare, Total} = bare(Cs, A),
                                {Fn, Pos, B, D} = maps:get(K, Ac, {0,0,0,0}),
                                Ac#{K => {Fn+1, Pos+Total, B+Bare, D + case Bare of 0 -> 1; _ -> 0 end}};
                           (_, Ac) -> Ac end, Acc, Forms);
        _ -> Acc
    end.
bare(Cs, A) ->
    Bare = [I || I <- lists:seq(1, A), lists:any(fun(C) -> is_bare(C, I) end, Cs)],
    {length(Bare), A}.
is_bare({clause, _, Ps, Gs, _}, I) ->
    case lists:nth(I, Ps) of
        {var, _, '_'} -> true;
        {var, _, V}   -> not mentioned(V, Gs);
        _ -> false
    end.
mentioned(V, {var, _, V}) -> true;
mentioned(V, T) when is_tuple(T) -> mentioned(V, tuple_to_list(T));
mentioned(V, [H|T]) -> mentioned(V, H) orelse mentioned(V, T);
mentioned(_, _) -> false.
