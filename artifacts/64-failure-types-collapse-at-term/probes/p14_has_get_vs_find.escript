#!/usr/bin/env escript
%% P14: cost of the three erlang realisations of a lookup that can say "absent": maps:find (tagged), is_key+get (pair), get/3 with sentinel (bare, the ONLY unsound one at term)
main(_) ->
    N = 1000000,
    M = maps:from_list([{I, I*2} || I <- lists:seq(1, 1000, 2)]),
    Find = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case maps:find(I rem 1000, M) of error -> Acc; {ok, V} -> Acc + V end) end,
    Pair = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> K = I rem 1000, L(I+1, case maps:is_key(K, M) of false -> Acc; true -> Acc + maps:get(K, M) end) end,
    Dflt = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case maps:get(I rem 1000, M, nothing) of nothing -> Acc; V -> Acc + V end) end,
    [begin
        Ts = lists:sort([element(1, timer:tc(fun() -> F(1, 0) end)) || _ <- lists:seq(1,7)]),
        io:format("~-26s min ~7w med ~7w max ~7w us  result ~w~n", [Name, hd(Ts), lists:nth(4,Ts), lists:last(Ts), F(1,0)])
     end || {Name, F} <- [{"maps:find (tagged)", Find}, {"is_key + get (pair)", Pair}, {"get/3 sentinel (bare)", Dflt}]],
    %% the sentinel's unsoundness, executed: a stored 'nothing' reads as absent
    M2 = #{a => nothing},
    io:format("stored nothing, get/3 sentinel: ~p ; find: ~p~n", [maps:get(a, M2, nothing), maps:find(a, M2)]).
