%%% timing.erl -- INTERLEAVED round-robin timing of loaded variant modules.
%%% usage: erl -noshell -pa build -run timing main <input> <rounds> mod1 mod2 ...
%%% Each round calls every module once (order rotated each round to cancel position bias),
%%% so machine drift hits all variants equally. Reports n, min, p10, median, p90, max, stdev (ms)
%%% and checks every variant returns the same answer as the first.
-module(timing).
-export([main/1]).

main([In, RoundsS | Mods0]) ->
    Rounds = list_to_integer(RoundsS),
    Mods = [list_to_atom(M) || M <- Mods0],
    Deltas = read(In),
    Ans = [{M, M:part_two(Deltas)} || M <- Mods],
    [{_, A0} | _] = Ans,
    case [M || {M, A} <- Ans, A =/= A0] of
        [] -> io:format("answer ~p (all ~p variants agree)~n", [A0, length(Mods)]);
        Bad -> io:format("ANSWER MISMATCH ~p~n", [Bad]), halt(1)
    end,
    [[M:part_two(Deltas) || _ <- lists:seq(1, 20)] || M <- Mods],
    N = length(Mods),
    Acc = lists:foldl(
            fun(R, Map) ->
                    lists:foldl(fun(M, Mp) ->
                                        erlang:garbage_collect(),
                                        {T, _} = timer:tc(M, part_two, [Deltas]),
                                        maps:update_with(M, fun(L) -> [T | L] end, [T], Mp)
                                end, Map, rotate(Mods, R rem N))
            end, #{}, lists:seq(1, Rounds)),
    Stats = [{M, stats(maps:get(M, Acc))} || M <- Mods],
    io:format("~-18s ~6s ~8s ~8s ~8s ~8s ~8s ~7s ~8s~n",
              [variant, n, min, p10, median, p90, max, stdev, med_rel]),
    {_, #{median := BaseMed}} = hd(Stats),
    [io:format("~-18s ~6w ~8.3f ~8.3f ~8.3f ~8.3f ~8.3f ~7.3f ~7.3fx~n",
               [M, Rounds, V(min, S), V(p10, S), V(median, S), V(p90, S), V(max, S), V(sd, S),
                maps:get(median, S) / BaseMed])
     || {M, S} <- Stats, V <- [fun(K, X) -> maps:get(K, X) / 1000 end]],
    halt().

stats(L) ->
    S = lists:sort(L), N = length(S),
    Mean = lists:sum(S) / N,
    Var = lists:sum([(X - Mean) * (X - Mean) || X <- S]) / N,
    #{min => hd(S), p10 => lists:nth(max(1, N div 10), S), median => lists:nth(N div 2 + 1, S),
      p90 => lists:nth(min(N, (N * 9) div 10), S), max => lists:last(S), sd => math:sqrt(Var)}.

rotate(L, 0) -> L;
rotate([H | T], K) -> rotate(T ++ [H], K - 1).

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
