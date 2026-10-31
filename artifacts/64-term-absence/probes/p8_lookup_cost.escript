#!/usr/bin/env escript
%% p8: runtime cost of the three Erlang idioms a B# lowering could use, on a hit and
%% a miss, small (20 keys) and large (100000 keys) maps. Microseconds per 1e6 lookups,
%% median of 7. Noise is real (shared VM); read ratios, not absolutes.
%% Run: escript p8_lookup_cost.escript > p8_lookup_cost.out
%% Exit 1 if is_key+get is NOT slower than find on a hit at the large map (the claim it tests).
-mode(compile).
main(_) ->
    Small = maps:from_list([{I, I} || I <- lists:seq(1, 20)]),
    Large = maps:from_list([{I, I} || I <- lists:seq(1, 100000)]),
    N = 1000000,
    Idioms = [{"maps:find/2 (tagged)",       fun(K, M) -> case maps:find(K, M) of {ok, V} -> V; error -> absent end end},
              {"maps:get/3 (untagged)",      fun(K, M) -> maps:get(K, M, nothing) end},
              {"is_key + get (Has then Get)",fun(K, M) -> case maps:is_key(K, M) of true -> maps:get(K, M); false -> absent end end}],
    Cases = [{"small hit", Small, 7}, {"small miss", Small, 99}, {"large hit", Large, 77777}, {"large miss", Large, 999999}],
    Res = [{CN, IN, med(fun() -> loop(N, F, K, M) end)} || {CN, M, K} <- Cases, {IN, F} <- Idioms],
    [io:format("~-12s ~-30s ~8w us / 1e6~n", [C, I, T]) || {C, I, T} <- Res],
    Get = fun(C, I) -> hd([T || {C0, I0, T} <- Res, C0 =:= C, I0 =:= I]) end,
    R = Get("large hit", "is_key + get (Has then Get)") / Get("large hit", "maps:find/2 (tagged)"),
    io:format("ratio is_key+get / find on large hit: ~.2f~n", [R]),
    case R > 1.0 of true -> io:format("ASSERT holds~n"), halt(0); false -> io:format("ASSERT FAILS~n"), halt(1) end.
loop(0, _, _, _) -> ok;
loop(N, F, K, M) -> _ = F(K, M), loop(N - 1, F, K, M).
med(Fun) -> Ts = lists:sort([element(1, timer:tc(Fun)) || _ <- lists:seq(1, 7)]), lists:nth(4, Ts).
