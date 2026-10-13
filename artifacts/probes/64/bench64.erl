%% Ticket 64 P4b: bare-with-sentinel lookup vs tagged lookup. Compiled (not erl_eval), 5M iterations, median of 11.
-module(bench64).
-export([main/0]).
bare(0, _M, A) -> A;
bare(I, M, A) -> bare(I - 1, M, case maps:get(k, M, nothing) of nothing -> A; V -> A + V end).
tagged(0, _M, A) -> A;
tagged(I, M, A) -> tagged(I - 1, M, case maps:find(k, M) of {ok, V} -> A + V; error -> A end).
tagged_miss(0, _M, A) -> A;
tagged_miss(I, M, A) -> tagged_miss(I - 1, M, case maps:find(zz, M) of {ok, V} -> A + V; error -> A end).
bare_miss(0, _M, A) -> A;
bare_miss(I, M, A) -> bare_miss(I - 1, M, case maps:get(zz, M, nothing) of nothing -> A; V -> A + V end).
med(F) -> L = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1, 11)]), lists:nth(6, L).
main() ->
    N = 5000000, M = #{k => 7},
    P = fun(Name, F) -> io:format("~-34s ~.2f ns/op~n", [Name, med(F) * 1000 / N]) end,
    P("bare+sentinel, key present", fun() -> bare(N, M, 0) end),
    P("tagged {ok,V}, key present", fun() -> tagged(N, M, 0) end),
    P("bare+sentinel, key absent", fun() -> bare_miss(N, M, 0) end),
    P("tagged, key absent", fun() -> tagged_miss(N, M, 0) end).
