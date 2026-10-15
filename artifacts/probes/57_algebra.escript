#!/usr/bin/env escript
%%! -noshell
%% 57_algebra -- ticket claim: "subtract(-10..10, 0) is -10..-1 | 1..10" (the algebra represents
%% negative bounds). REFUTED by: any output other than the two intervals below.
main([V57]) ->
    Ebin = case V57 of "" -> os:getenv("REPO") ++ "/compiler/_build/default/lib/bsc/ebin";
                       _ -> V57 ++ "/stock/_build/default/lib/bsc/ebin" end,
    true = code:add_patha(Ebin),
    R = bs_types:subtract(bs_types:range(-10, 10), bs_types:range(0, 0)),
    io:format("subtract(-10..10, 0) = ~p~n", [R]),
    io:format("is_subtype(-10..-1, result) = ~p ; is_subtype(0..0, result) = ~p~n",
              [bs_types:is_subtype(bs_types:range(-10,-1), R), bs_types:is_subtype(bs_types:range(0,0), R)]).
