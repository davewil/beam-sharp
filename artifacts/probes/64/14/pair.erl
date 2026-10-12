-module(pair).
-export([find/3, pair/3, get3/3, bench/0]).
%% Three ways to read a possibly-absent term value out of a map, the way the BEAM does them:
%%   find : maps:find(K, M)               -> {ok,V} | error     (one lookup, one 3-word tuple per hit)
%%   pair : maps:is_key(K, M) then maps:get(K, M)               (two lookups, no allocation)
%%   get3 : maps:get(K, M, Default)       -> V | Default        (one lookup, ambiguous if V can be Default)
-define(N, 3000000).
find(0, _, A) -> A;
find(N, M, A) -> case maps:find(N rem 1000, M) of {ok, V} -> find(N-1, M, A+V); error -> find(N-1, M, A) end.
pair(0, _, A) -> A;
pair(N, M, A) -> K = N rem 1000, case maps:is_key(K, M) of true -> pair(N-1, M, A + maps:get(K, M)); false -> pair(N-1, M, A) end.
get3(0, _, A) -> A;
get3(N, M, A) -> case maps:get(N rem 1000, M, absent) of absent -> get3(N-1, M, A); V -> get3(N-1, M, A+V) end.
t(F) -> {T, _} = timer:tc(F), T.
st(L) -> S = lists:sort(L), {hd(S), lists:nth((length(S)+1) div 2, S)}.
bench() ->
    M = maps:from_list([{I, I} || I <- lists:seq(0, 999)]),
    [pair:F(100000, M, 0) || F <- [find, pair, get3]],
    R = 9,
    Ts = [{t(fun() -> pair:find(?N, M, 0) end), t(fun() -> pair:pair(?N, M, 0) end), t(fun() -> pair:get3(?N, M, 0) end)} || _ <- lists:seq(1, R)],
    io:format("OTP ~s, ~p lookups/run, ~p runs, 1000-key small-int map, 100% hit, microseconds~n", [erlang:system_info(otp_release), ?N, R]),
    io:format("~-34s ~10s ~10s~n", ["variant", "min", "median"]),
    [begin {Mn, Md} = st([element(I, T) || T <- Ts]), io:format("~-34s ~10w ~10w~n", [Nm, Mn, Md]) end
     || {I, Nm} <- [{1, "maps:find  {ok,V}|error (1 lookup)"}, {2, "is_key + get   (2 lookups)"}, {3, "get/3 + sentinel (1 lookup)"}]].
