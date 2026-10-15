#!/usr/bin/env escript
main([NS, ItS | Vs]) ->
    N = list_to_integer(NS), Iters = list_to_integer(ItS),
    Variants = [begin [L, D] = string:split(V, "="), {L, element(2, file:read_file(D ++ "/T.beam"))} end || V <- Vs],
    R = #{'Kind' => 'T.R', 'A' => 1, 'B' => 2, 'C' => 3},
    Load = fun(Bin) -> code:purge('T'), code:delete('T'), code:purge('T'), {module, 'T'} = code:load_binary('T', "T.beam", Bin) end,
    Time = fun(F) -> {Us, _} = timer:tc(F), Us * 1000 / Iters end,
    Res = lists:foldl(fun(_, Acc) -> lists:foldl(fun({L, B}, A2) -> Load(B),
            TU = Time(fun() -> 'T':'RunU'([Iters]) end), TR = Time(fun() -> 'T':'RunR'(Iters, R) end),
            maps:update_with(L, fun({U, Rr}) -> {[TU|U], [TR|Rr]} end, {[TU],[TR]}, A2) end, Acc, Variants) end, #{}, lists:seq(1, N)),
    [begin {U, Rr} = maps:get(L, Res), io:format("~-5s RunU(unproven int) min=~.3f med=~.3f max=~.3f | RunR(record) min=~.3f med=~.3f max=~.3f~n", [L, lists:min(U), med(U), lists:max(U), lists:min(Rr), med(Rr), lists:max(Rr)]) end || {L,_} <- Variants].
med(L) -> S = lists:sort(L), lists:nth((length(L)+1) div 2, S).
