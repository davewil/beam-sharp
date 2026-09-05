-module(bench2).
-export([run/0]).

n() -> 50000000.
r() -> #{'Kind' => 'Loop.Order', 'Id' => 1, 'Total' => 7}.

time_it(F) ->
    Times = [begin {T,_} = timer:tc(F), T end || _ <- lists:seq(1,5)],
    lists:nth(3, lists:sort(Times)).

run() ->
    R = r(), N = n(),
    io:format("N=~p, median of 5~n", [N]),
    T1 = time_it(fun() -> 'Loop':'Sum'(R, N, 0) end),
    io:format("Loop:'Sum'/3 (exported, tag test on every recursive call): ~p us~n", [T1]),
    T2 = time_it(fun() -> 'Loop':'SumViaPrivate'(R, N, 0) end),
    io:format("Loop:'SumViaPrivate' -> private SumPriv (tag test once, at the public wrapper only): ~p us~n", [T2]),
    io:format("ratio Sum/SumViaPrivate: ~.3f~n", [T1/T2]),
    halt().
