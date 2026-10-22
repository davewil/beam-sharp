#!/usr/bin/env escript
%% Usage: bench.escript DIR... — time OuterL (1000 valid Orders -> private Inner per element, tag test present or not)
%% and SumO (1000 valid Octets -> private Bump) in each build dir; 9 repetitions, prints min/median/max ns per private call.
main(Dirs) ->
    Order = #{'Kind' => 'T.Order', 'Id' => 1, 'Total' => 10},
    Os = lists:duplicate(1000, Order),
    Xs = lists:duplicate(1000, 7),
    [begin
         code:purge('T'), code:delete('T'), code:add_patha(D), {module,'T'} = code:load_file('T'),
         R1 = rep(fun() -> 'T':'OuterL'(Os) end),
         R2 = rep(fun() -> 'T':'SumO'(Xs) end),
         code:del_path(D),
         io:format("~-40s Inner(tag):  ~s~n~-40s Bump(int):   ~s~n", [D, R1, "", R2])
     end || D <- Dirs].
rep(F) ->
    N = 3000,
    Ts = [begin {T,_} = timer:tc(fun() -> loop(N, F) end), T * 1000 / (N * 1000) end || _ <- lists:seq(1,9)],
    S = lists:sort(Ts),
    io_lib:format("min ~.2f  median ~.2f  max ~.2f  ns/call", [hd(S), lists:nth(5,S), lists:last(S)]).
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N-1, F).
