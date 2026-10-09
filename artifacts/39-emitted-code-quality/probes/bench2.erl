%% Interleaved harness: ROUNDS rounds, each round times every impl once in rotated order.
%% Usage: erl -pa ebin -pa extra... -s bench2 main InputPath Rounds Mod:Fun ...  (Label=Mod:Fun)
-module(bench2).
-export([main/1]).
main([In, RoundsS | Specs]) ->
    Rounds = list_to_integer(RoundsS),
    {ok, Bin} = file:read_file(In),
    Ds = [p(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Impls = [begin [L, M, F] = string:split(S, ":", all),
                   {L, list_to_atom(M), list_to_atom(F)} end || S <- Specs],
    [io:format("answer ~s = ~p~n", [L, M:F(Ds)]) || {L, M, F} <- Impls],
    Acc0 = maps:from_list([{L, []} || {L,_,_} <- Impls]),
    Acc = lists:foldl(fun(R, A) ->
            Rot = rot(Impls, R rem length(Impls)),
            lists:foldl(fun({L,M,F}, A1) ->
                  {T,_} = timer:tc(M, F, [Ds]), maps:update_with(L, fun(X)->[T|X] end, A1) end, A, Rot)
          end, Acc0, lists:seq(1, Rounds)),
    Base = lists:min([lists:min(maps:get(L, Acc)) || {L,_,_} <- Impls]),
    io:format("~-14s ~8s ~8s ~8s ~8s ~7s~n", ["impl","min ms","med ms","p90 ms","max ms","min/best"]),
    [begin S = lists:sort(maps:get(L, Acc)), N = length(S),
           io:format("~-14s ~8.2f ~8.2f ~8.2f ~8.2f ~6.3fx~n",
             [L, hd(S)/1000, lists:nth(N div 2 + 1, S)/1000, lists:nth(max(1,round(N*0.9)), S)/1000,
              lists:last(S)/1000, hd(S)/Base]) end || {L,_,_} <- Impls],
    halt().
rot(L, 0) -> L; rot([H|T], N) -> rot(T ++ [H], N-1).
p([$L|N]) -> -list_to_integer(N);
p([$R|N]) -> list_to_integer(N).
