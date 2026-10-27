-module(bench_variants).
-export([main/1]).
-define(ROUNDS, 60).
%% Loads bench_erl from several dirs under different module names is impossible (same name), so each
%% variant runs in its own fresh node-less process via code:load_abs after purge, interleaved by rounds.
main([Dir0, P0]) ->
    Dir = atom_to_list(Dir0), P = atom_to_list(P0),
    Ds = read(P),
    Vs = ["d", "d2", "nt", "ns"],
    Res = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun(V, A) ->
            code:purge(bench_erl), code:delete(bench_erl),
            {module, _} = code:load_abs(Dir ++ "/" ++ V ++ "/bench_erl"),
            6770 = bench_erl:part_two(Ds),
            erlang:garbage_collect(),
            {T, _} = timer:tc(fun bench_erl:part_two/1, [Ds]),
            maps:update_with(V, fun(L) -> [T|L] end, [T], A)
        end, Acc, Vs) end, #{}, lists:seq(1, ?ROUNDS)),
    Base = lists:min([lists:min(L) || L <- maps:values(Res)]),
    [begin S = lists:sort(L), M = lists:min(L),
        io:format("~-3s min ~7.2f ms  median ~7.2f ms  p90 ~7.2f  rel-min ~5.3f~n",
            [V, M/1000, lists:nth(?ROUNDS div 2 + 1, S)/1000, lists:nth(round(?ROUNDS*0.9), S)/1000, M/Base]) end
     || V <- Vs, L <- [maps:get(V, Res)]],
    halt().
read(P) ->
    {ok, B} = file:read_file(P),
    [parse(L) || L <- string:split(binary_to_list(B), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
