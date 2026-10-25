#!/usr/bin/env escript
%% Probe 17: Erlang parses a quoted-atom remote call; the unquoted spelling is a different (variable) parse.
main(_) ->
    lists:foreach(fun(Src) ->
        {ok, Toks, _} = erl_scan:string(Src ++ "."),
        R = case erl_parse:parse_exprs(Toks) of
                {ok, [{call, _, {remote, _, M, F}, _}]} -> {call, element(1, M), element(1, F)};
                {ok, Other} -> {other, Other};
                {error, E} -> {error, E}
            end,
        io:format("~-24s ~p~n", [Src, R]) end,
        ["'Shop':'New'(1)", "Shop:New(1)", "shop:new(1)"]).
