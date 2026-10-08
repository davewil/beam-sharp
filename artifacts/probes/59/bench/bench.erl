-module(bench).
-export([main/0]).
%% Probe 59f: call-time cost. 15 interleaved rounds per workload, variants: BenchBase (shipped emitter), BenchBas2
%% (byte-identical source & emitter, different name: the NOISE FLOOR), BenchTagA (tag test exported-only),
%% BenchKndB (kind/range tests also on private).
-define(ROUNDS, 15).
load(M) -> code:purge(M), code:delete(M), {module, M} = code:load_abs("out/" ++ atom_to_list(M)).
rec() -> #{'Kind' => 'BenchBase.Rec', 'A' => 1, 'B' => 2, 'C' => 3}.
rec(M) -> #{'Kind' => list_to_atom(atom_to_list(M) ++ ".Rec"), 'A' => 1, 'B' => 2, 'C' => 3}.
workloads() ->
    Xs = lists:seq(1, 1000),
    [{"W1 tag: private rec fn, 2 tag tests/iter (20M iters)", 20000000,
        fun(M, N) -> M:'RunRec'(rec(M), N) end},
     {"W2 kind: private int loop, caller proven (50M iters)", 50000000,
        fun(M, N) -> M:'RunInt'(N) end},
     {"W3 kind: private fn mapped over list, unknown callers (20M elems)", 20000000,
        fun(M, N) -> lists:foreach(fun(_) -> M:'RunMap'(Xs) end, lists:seq(1, N div 1000)) end},
     {"W4 kind: private loop, UNKNOWN-typed seed (20M iters)", 20000000,
        fun(M, N) -> M:'RunSeed'([0], N) end}].
time(F) -> T0 = erlang:monotonic_time(nanosecond), F(), erlang:monotonic_time(nanosecond) - T0.
stats(L) -> S = lists:sort(L), {hd(S), lists:nth((length(S) + 1) div 2, S), lists:last(S)}.
main() ->
    Ms = ['BenchBase', 'BenchBas2', 'BenchTagA', 'BenchKndB'],
    [load(M) || M <- Ms],
    [begin
         io:format("~n~s~n", [Name]),
         F(hd(Ms), N div 10),  %% warm up
         Res = lists:foldl(fun(_, Acc) ->
                  lists:foldl(fun(M, A) -> T = time(fun() -> F(M, N) end), maps:update_with(M, fun(L) -> [T | L] end, [T], A) end, Acc, Ms)
               end, #{}, lists:seq(1, ?ROUNDS)),
         [begin {Min, Med, Max} = stats(maps:get(M, Res)),
                io:format("  ~-10s ns/iter  min ~7.3f  median ~7.3f  max ~7.3f  (spread max-min ~5.3f)~n",
                          [M, Min / N, Med / N, Max / N, (Max - Min) / N]) end || M <- Ms]
     end || {Name, N, F} <- workloads()],
    halt().
