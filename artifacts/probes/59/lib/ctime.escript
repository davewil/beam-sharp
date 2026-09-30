#!/usr/bin/env escript
%% usage: ctime.escript EbinDir SrcFile Runs -- in-VM compile time of one .bs file via bsc:file_to_dir/2 (1 warm-up + Runs), min/median ms
main([Ebin, Src, RunsS]) ->
    code:add_patha(Ebin), Runs = list_to_integer(RunsS),
    Out = "/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/59/ctime-out", filelib:ensure_dir(Out ++ "/x"),
    F = fun() -> bsc:file_to_dir(Src, Out) end,
    F(),
    Ts = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1, Runs)]),
    io:format("min=~.1f ms median=~.1f ms (N=~p)~n", [hd(Ts)/1000, lists:nth((Runs+1) div 2, Ts)/1000, Runs]).
