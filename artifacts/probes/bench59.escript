#!/usr/bin/env escript
%% bench59.escript EBIN : private-call cost with and without the int kind test (Weigh/1 is private)
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Tmp = os:cmd("mktemp -d") -- "\n",
    Src = os:getenv("BENCH_SRC"),
    ModDir = filename:join(Tmp, "Bn"), ok = filelib:ensure_dir(ModDir ++ "/x"),
    {ok,_} = file:copy(Src, filename:join(ModDir, "a.bs")),
    {ok,_} = bsc:file_to_dir(filename:join(ModDir, "a.bs"), Tmp),
    true = code:add_patha(Tmp), {module,'Bn'} = code:load_abs(filename:join(Tmp,"Bn")),
    Xs = [I rem 20 || I <- lists:seq(1, 2000000)],
    _ = 'Bn':'Run'(Xs),
    Ts = [element(1, timer:tc(fun() -> 'Bn':'Run'(Xs) end)) || _ <- lists:seq(1, 41)],
    S = lists:sort(Ts),
    io:format("min ~.2f ms  median ~.2f ms  (2M private calls/run, 41 runs)~n",
              [hd(S)/1000, lists:nth(21, S)/1000]).
