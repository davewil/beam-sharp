#!/usr/bin/env escript
%% usage: bench.escript Ndir Runs  -- runs each hot loop (1e7 iterations), 1 warm-up + Runs timed; prints min/median us and ns per call
main([Dir, RunsS]) ->
    code:add_patha(Dir),
    Runs = list_to_integer(RunsS), N = 10000000,
    Order = #{'Kind'=>'Bench.Order','Id'=>1,'Total'=>3},
    Cases = [{"RecP  (private, record param, self-call)", fun() -> 'Bench':'RunRec'(Order, N) end},
             {"IntP  (private, int unproved by caller)",  fun() -> 'Bench':'RunIntKept'([7], N) end},
             {"IntP  (private, int proved by caller)",    fun() -> 'Bench':'RunIntProven'(7, N) end},
             {"IntE  (EXPORTED self-recursive, int)",     fun() -> 'Bench':'IntE'(7, N, 0) end}],
    lists:foreach(fun({Name, F}) ->
        F(),
        Ts = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1, Runs)]),
        Min = hd(Ts), Med = lists:nth((Runs+1) div 2, Ts),
        io:format("~-45s min=~7w us  median=~7w us  min=~6.2f ns/call  median=~6.2f ns/call~n",
                  [Name, Min, Med, Min*1000/N, Med*1000/N])
    end, Cases).
