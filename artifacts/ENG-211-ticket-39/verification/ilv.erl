-module(ilv).
-export([main/1]).
-define(R, 120).
main([P0, Ord0]) -> P = atom_to_list(P0), Ord = atom_to_list(Ord0),
    {ok, B} = file:read_file(P),
    Ds = [parse(L) || L <- string:split(binary_to_list(B), "\n", all), L =/= ""],
    All = #{"erl" => fun bench_erl:part_two/1, "erl2" => fun bench_erl2:part_two/1,
            "ex" => fun 'Elixir.BenchEx':part_two/1, "bsc" => fun 'Day01':'PartTwo'/1},
    Names = string:tokens(Ord, ","),
    [6770 = (maps:get(N, All))(Ds) || N <- Names],
    Res = lists:foldl(fun(_, Acc) -> lists:foldl(fun(N, A) ->
        erlang:garbage_collect(), {T,_} = timer:tc(maps:get(N, All), [Ds]),
        maps:update_with(N, fun(L) -> [T|L] end, [T], A) end, Acc, Names) end, #{}, lists:seq(1,?R)),
    Base = lists:min([lists:min(L) || L <- maps:values(Res)]),
    [begin S = lists:sort(L), Med = lists:nth(?R div 2 + 1, S),
       io:format("~-5s min ~6.2f med ~6.2f  rel-min ~5.3f~n", [N, hd(S)/1000, Med/1000, hd(S)/Base]) end || N <- Names, L <- [maps:get(N, Res)]],
    halt().
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
