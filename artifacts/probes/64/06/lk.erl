-module(lk).
-export([bare/3, ok/3, nbare/3, nok/3, bench/0]).
%% Lookup loop over a map: sum the values found, count misses.
%% bare: found value returned as-is, absent returned as the atom 'absent' (the option<T> shape).
%% ok:   found value returned as {ok,V}, absent as 'absent'            (the tagged shape).
%% Consumers are written the way a B# switch would be lowered: a case on the result.
-define(N, 3000000).

get_bare(K, M) -> case M of #{K := V} -> V; #{} -> absent end.
get_ok(K, M)   -> case M of #{K := V} -> {ok, V}; #{} -> absent end.

%% hit-ratio selects keys: Keys is a tuple of keys, cycled.
bare(0, _M, Acc) -> Acc;
bare(N, M, Acc) -> bare_(N, M, Acc, N rem 1000).
bare_(N, M, Acc, K) ->
    case get_bare(K, M) of
        absent -> bare(N - 1, M, Acc);
        V when is_integer(V) -> bare(N - 1, M, Acc + V);
        _ -> bare(N - 1, M, Acc + 1)
    end.
ok(0, _M, Acc) -> Acc;
ok(N, M, Acc) -> ok_(N, M, Acc, N rem 1000).
ok_(N, M, Acc, K) ->
    case get_ok(K, M) of
        absent -> ok(N - 1, M, Acc);
        {ok, V} when is_integer(V) -> ok(N - 1, M, Acc + V);
        {ok, _} -> ok(N - 1, M, Acc + 1)
    end.
nbare(N, M, Acc) -> bare(N, M, Acc).
nok(N, M, Acc) -> ok(N, M, Acc).

time(F) -> {T, _} = timer:tc(F), T.
stats(L) -> S = lists:sort(L), {hd(S), lists:nth((length(S) + 1) div 2, S)}.

bench() ->
    Runs = 9,
    Cases = [{"V small int, 100% hit (keys 0..999 all present)", maps:from_list([{I, I} || I <- lists:seq(0, 999)])},
             {"V small int,  50% hit (keys 0..499 present)", maps:from_list([{I, I} || I <- lists:seq(0, 499)])},
             {"V 3-list,    100% hit", maps:from_list([{I, [I, I, I]} || I <- lists:seq(0, 999)])}],
    io:format("OTP ~s, ~p lookups per run, ~p runs, microseconds~n", [erlang:system_info(otp_release), ?N, Runs]),
    io:format("~-52s ~12s ~12s ~12s ~12s~n", ["case", "bare min", "bare med", "tagged min", "tagged med"]),
    lists:foreach(fun({Name, M}) ->
        %% warm up
        lk:nbare(100000, M, 0), lk:nok(100000, M, 0),
        %% interleave to cancel drift
        Ts = [{time(fun() -> lk:nbare(?N, M, 0) end), time(fun() -> lk:nok(?N, M, 0) end)} || _ <- lists:seq(1, Runs)],
        {B1, B2} = stats([B || {B, _} <- Ts]),
        {O1, O2} = stats([O || {_, O} <- Ts]),
        io:format("~-52s ~12w ~12w ~12w ~12w~n", [Name, B1, B2, O1, O2])
    end, Cases).
