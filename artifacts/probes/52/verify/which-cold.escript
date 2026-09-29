#!/usr/bin/env escript
%% EXPECTED (before run): first which() on an unloaded module in a fresh VM is >= the 0.5ms warm repeat; which on a module that IS loaded is us-scale.
main(_) ->
    Med = fun(L) -> S = lists:sort(L), lists:nth((length(S)+1) div 2, S) end,
    Batch = fun(F, N) -> {US,_} = timer:tc(fun() -> lp(N, F) end), US/N end,
    io:format("zip loaded before? ~p~n", [code:is_loaded(zip)]),
    {F1,P1} = timer:tc(fun() -> code:which(zip) end),
    io:format("FIRST which(zip) ~p us -> ~p~n", [F1,P1]),
    {F2,_} = timer:tc(fun() -> code:which(zip) end),
    io:format("SECOND which ~p us~n", [F2]),
    W = [Batch(fun() -> code:which(zip) end, 100) || _ <- lists:seq(1,12)],
    io:format("unloaded repeat N=100x12 min ~.1f med ~.1f us~n", [lists:min(W), Med(W)]),
    R = code:ensure_loaded(zip), io:format("ensure_loaded ~p ~p~n", [R, element(1,{code:is_loaded(zip)})]),
    Wl = [Batch(fun() -> code:which(zip) end, 2000) || _ <- lists:seq(1,12)],
    io:format("LOADED which N=2000x12 min ~.2f med ~.2f us~n", [lists:min(Wl), Med(Wl)]),
    Wp = [Batch(fun() -> code:which(lists) end, 2000) || _ <- lists:seq(1,12)],
    io:format("which(lists) (loaded stdlib) min ~.2f med ~.2f us~n", [lists:min(Wp), Med(Wp)]).
lp(0,_) -> ok; lp(N,F) -> F(), lp(N-1,F).
