-module(bench_call).
-export([main/0, local_loop/2, remote_loop/2]).
%% Cost of a helper that sits in the same module (local call) against one that
%% sits in another module (remote call), which is what a module-granular
%% restriction forces. Same helper body. N calls per run; 25 warm runs.
-define(N, 5000000).
helper(X) -> X + 100.
local_loop(0, A) -> A;
local_loop(N, A) -> local_loop(N - 1, helper(A) band 16#FFFF).
remote_loop(0, A) -> A;
remote_loop(N, A) -> remote_loop(N - 1, bench_helper:helper(A) band 16#FFFF).
time(F) -> {T, _} = timer:tc(F), T.
main() ->
    _ = [time(fun() -> local_loop(?N, 0) end) || _ <- lists:seq(1, 5)],
    _ = [time(fun() -> remote_loop(?N, 0) end) || _ <- lists:seq(1, 5)],
    %% interleaved so drift hits both
    Runs = [{time(fun() -> local_loop(?N, 0) end), time(fun() -> remote_loop(?N, 0) end)}
            || _ <- lists:seq(1, 25)],
    L = lists:sort([A || {A, _} <- Runs]), R = lists:sort([B || {_, B} <- Runs]),
    io:format("~p calls per run, 25 runs, microseconds~n", [?N]),
    io:format("local : min ~p median ~p max ~p~n", [hd(L), lists:nth(13, L), lists:last(L)]),
    io:format("remote: min ~p median ~p max ~p~n", [hd(R), lists:nth(13, R), lists:last(R)]),
    io:format("noise (local max-min) ~p us; per-call delta of medians ~.2f ns~n",
              [lists:last(L) - hd(L), (lists:nth(13, R) - lists:nth(13, L)) * 1000 / ?N]).
