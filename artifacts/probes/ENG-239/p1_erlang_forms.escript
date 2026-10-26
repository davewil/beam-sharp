#!/usr/bin/env escript
%% P1: what erl_scan + erl_parse produce for `-5` in a guard, a pattern, an
%% expression, and for `0-5` / `2+3`. Pure parser output, no later pass.
main(_) ->
    lists:foreach(fun(S) -> show(S) end, [
        "f(X) when X >= -5 -> a.",
        "f(X) when X >= 0-5 -> a.",
        "f(X) when X >= 2+3 -> a.",
        "f(-5) -> a.",
        "f(X) -> X + -5."
    ]).
show(Src) ->
    {ok, Ts, _} = erl_scan:string(Src),
    {ok, F} = erl_parse:parse_form(Ts),
    io:format("~s~n   ~w~n", [Src, strip(F)]).
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tl_anno(tuple_to_list(T))]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(X) -> X.
tl_anno([T, _Anno | R]) -> [T | R];
tl_anno(L) -> L.
