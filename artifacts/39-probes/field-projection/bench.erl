-module(bench).
-export([run/0]).

n() -> 50000000.

r() -> #{'Kind' => 'Loop.Order', 'Id' => 1, 'Total' => 7}.

time_it(F) ->
    Times = [begin
        {T, _} = timer:tc(F),
        T
    end || _ <- lists:seq(1, 5)],
    Sorted = lists:sort(Times),
    lists:nth(3, Sorted). % median of 5

run() ->
    R = r(),
    N = n(),
    io:format("N=~p iterations, median of 5 trials, microseconds~n", [N]),
    T1 = time_it(fun() -> 'Loop':'Sum'(R, N, 0) end),
    io:format("Loop:'Sum'/3      (bsc, erlang:map_get/2 via bif)  : ~p us~n", [T1]),
    T2 = time_it(fun() -> loop_mapget:sum(R, N, 0) end),
    io:format("loop_mapget:sum/3 (hand, erlang:map_get/2 via bif) : ~p us~n", [T2]),
    T3 = time_it(fun() -> loop_case:sum(R, N, 0) end),
    io:format("loop_case:sum/3   (hand, get_map_elements)         : ~p us~n", [T3]),
    io:format("Loop vs loop_case ratio: ~.3f~n", [T1 / T3]),
    io:format("loop_mapget vs loop_case ratio (isolates map_get vs get_map_elements): ~.3f~n", [T2 / T3]),
    halt().
