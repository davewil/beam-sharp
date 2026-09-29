#!/usr/bin/env escript
%% EXPECTED: Elixir.Enum hit (deep in path) ~0.5ms repeat; first call larger.
main(_) ->
    B = fun(F,N) -> {U,_} = timer:tc(fun() -> lp(N,F) end), U/N end,
    {F1,P} = timer:tc(fun() -> code:which('Elixir.Enum') end),
    W = [B(fun() -> code:which('Elixir.Enum') end,100) || _ <- lists:seq(1,12)],
    io:format("~p~nfirst ~p us  repeat min ~.1f med ~.1f  pathlen ~p pos ~p~n",[P,F1,lists:min(W),lists:nth(6,lists:sort(W)),length(code:get_path()), length(lists:takewhile(fun(D)-> not lists:prefix("/usr/lib/elixir/lib/elixir", D) end, code:get_path()))]).
lp(0,_) -> ok; lp(N,F) -> F(), lp(N-1,F).
