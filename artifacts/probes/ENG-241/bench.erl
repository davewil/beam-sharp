-module(bench).
-export([run/0]).
%% 10M calls through an exported function; the loop is identical, only the guard differs.
-define(N, 10000000).
run() ->
    M = #{'Kind' => order, 'Total' => 5},
    Variants = [{tag_no, fun s_tag0:f/1}, {tag_yes, fun s_tag1:f/1}],
    IntV = [{int_no, fun s_int0:f/1}, {int_yes, fun s_int1:f/1}],
    [report(Name, F, M) || {Name, F} <- Variants],
    [report(Name, F, 41) || {Name, F} <- IntV],
    %% interleaved second pass to expose drift
    [report(Name ++ "(2nd pass)", F, M) || {Name0, F} <- Variants, Name <- [atom_to_list(Name0)]],
    [report(Name ++ "(2nd pass)", F, 41) || {Name0, F} <- IntV, Name <- [atom_to_list(Name0)]],
    ok.
report(Name, F, Arg) ->
    Ts = [element(1, timer:tc(fun() -> loop(?N, F, Arg) end)) || _ <- lists:seq(1, 9)],
    S = lists:sort(Ts),
    io:format("~-22s min ~6.2f ns/call  median ~6.2f  max ~6.2f  (9 runs x 10M)~n",
              [Name, hd(S)*1000/?N, lists:nth(5, S)*1000/?N, lists:last(S)*1000/?N]).
loop(0, _, _) -> ok;
loop(K, F, A) -> F(A), loop(K-1, F, A).
