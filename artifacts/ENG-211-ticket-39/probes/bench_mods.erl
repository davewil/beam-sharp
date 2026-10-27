-module(bench_mods).
-export([main/1]).
-define(ROUNDS, 60).
%% Interleaved timing of several modules that each export part_two/1. Round-robin so drift hits all alike.
main([P | Ms0]) ->
    Ms = [list_to_atom(atom_to_list(M)) || M <- Ms0],
    Ds = read(atom_to_list(P)),
    [6770 = M:part_two(Ds) || M <- Ms],
    Res = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun(M, A) ->
            erlang:garbage_collect(),
            {T, _} = timer:tc(M, part_two, [Ds]),
            maps:update_with(M, fun(L) -> [T|L] end, [T], A) end, Acc, Ms) end, #{}, lists:seq(1, ?ROUNDS)),
    Base = lists:min([lists:min(L) || L <- maps:values(Res)]),
    [begin S = lists:sort(L),
        io:format("~-4s min ~7.2f ms  median ~7.2f ms  rel-min ~5.3f  rel-median ~5.3f~n",
          [M, lists:min(L)/1000, lists:nth(?ROUNDS div 2 + 1, S)/1000, lists:min(L)/Base,
           lists:nth(?ROUNDS div 2 + 1, S)/lists:nth(?ROUNDS div 2 + 1, lists:sort(maps:get(hd(Ms), Res)))]) end
     || M <- Ms, L <- [maps:get(M, Res)]],
    halt().
read(P) ->
    {ok, B} = file:read_file(P),
    [parse(L) || L <- string:split(binary_to_list(B), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
