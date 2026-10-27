-module(bench_rec).
-export([main/1]).
-define(ROUNDS, 40).
-define(N, 2000000).
main(_) ->
    Fs = [{"bsc RecLoop (private Spin, tag test emitted)", fun() -> 'RecLoop':'Run'(?N) end},
          {"erl hand: with tag test (control)",              fun() -> recloop_erl:run_guard(?N) end},
          {"erl hand: no tag test",                          fun() -> recloop_erl:run_noguard(?N) end},
          {"erl hand: no tag test (noise control)",          fun() -> recloop_erl:run_noguard(?N) end}],
    Expect = (?N * (?N + 1)) div 2,
    [Expect = F() || {_, F} <- Fs],
    Res = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun({Nm, F}, A) -> erlang:garbage_collect(), {T, _} = timer:tc(F),
            maps:update_with(Nm, fun(L) -> [T|L] end, [T], A) end, Acc, Fs) end, #{}, lists:seq(1, ?ROUNDS)),
    Base = lists:min([lists:min(L) || L <- maps:values(Res)]),
    [begin L = maps:get(Nm, Res), S = lists:sort(L),
        io:format("~-48s min ~7.2f ms  med ~7.2f  rel-min ~5.3f~n", [Nm, lists:min(L)/1000, lists:nth(?ROUNDS div 2 + 1, S)/1000, lists:min(L)/Base]) end || {Nm, _} <- Fs],
    halt().
