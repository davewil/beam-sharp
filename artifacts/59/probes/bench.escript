#!/usr/bin/env escript
%% bench.escript BEAMDIR Mod Fun N REPS  -- median/min/max microseconds of Mod:Fun(List) over REPS runs
main([Dir, Mod, Fun, NS, RS]) ->
    code:add_patha(Dir), M = list_to_atom(Mod), F = list_to_atom(Fun),
    {module, M} = code:load_abs(filename:join(Dir, Mod)),
    L = lists:seq(1, list_to_integer(NS)),
    _ = M:F(L),
    Ts = lists:sort([element(1, timer:tc(fun() -> M:F(L) end)) || _ <- lists:seq(1, list_to_integer(RS))]),
    io:format("~s: median=~pus min=~pus max=~pus (n=~s, reps=~s)~n",
              [Dir, lists:nth((length(Ts) + 1) div 2, Ts), hd(Ts), lists:last(Ts), NS, RS]).
