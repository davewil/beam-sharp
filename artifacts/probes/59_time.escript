#!/usr/bin/env escript
%% 59_time.escript N ITERS DIR=LABEL... -- load module T from each DIR (same module name), time
%% RunR(ITERS, R) and RunI(ITERS) N times each, ROUND-ROBIN across variants (so machine drift hits
%% all variants equally), after one warm-up call each. Prints min / median ns per iteration.
main([NS, ItS | Vs]) ->
    N = list_to_integer(NS), Iters = list_to_integer(ItS),
    Variants = [begin [L, D] = string:split(V, "="), {L, element(2, file:read_file(D ++ "/T.beam"))} end || V <- Vs],
    R = #{'Kind' => 'T.R', 'A' => 1, 'B' => 2, 'C' => 3},
    Load = fun(Bin) -> code:purge('T'), code:delete('T'), code:purge('T'),
                       {module, 'T'} = code:load_binary('T', "T.beam", Bin) end,
    Time = fun(F) -> {Us, _} = timer:tc(F), Us * 1000 / Iters end,
    [begin Load(B), 'T':'RunR'(1000, R), 'T':'RunI'(1000) end || {_, B} <- Variants],
    Results = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun({L, B}, A2) ->
            Load(B),
            TR = Time(fun() -> Iters = 'T':'RunR'(Iters, R) div 1 end),
            TI = Time(fun() -> _ = 'T':'RunI'(Iters) end),
            maps:update_with(L, fun({Rs, Is}) -> {[TR|Rs], [TI|Is]} end, {[TR], [TI]}, A2)
        end, Acc, Variants) end, #{}, lists:seq(1, N)),
    io:format("n=~p runs, ~p iterations each, ns/iteration~n", [N, Iters]),
    [begin {Rs, Is} = maps:get(L, Results),
           io:format("~-8s RunR(record loop) min=~7.3f median=~7.3f max=~7.3f | RunI(int loop) min=~7.3f median=~7.3f max=~7.3f~n",
                     [L, lists:min(Rs), med(Rs), lists:max(Rs), lists:min(Is), med(Is), lists:max(Is)]) end || {L, _} <- Variants].
med(L) -> S = lists:sort(L), lists:nth((length(L) + 1) div 2, S).
