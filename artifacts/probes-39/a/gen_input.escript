#!/usr/bin/env escript
%% deterministic input: 4732 rotations, total |delta| = 673364 (matches aoc/bench/README.md; the real puzzle input is not in the repo)
main([Out]) ->
    rand:seed(exsss, {39, 211, 2026}),
    N = 4732, Target = 673364,
    Raw = [1 + rand:uniform(283) || _ <- lists:seq(1, N-1)],
    Last = Target - lists:sum(Raw),
    true = Last > 0,
    All = Raw ++ [Last],
    Lines = [ [case rand:uniform(2) of 1 -> $L; 2 -> $R end | integer_to_list(X)] || X <- All],
    ok = file:write_file(Out, [[L, $\n] || L <- Lines]),
    io:format("~p rotations, sum ~p, last ~p~n", [length(All), lists:sum(All), Last]).
