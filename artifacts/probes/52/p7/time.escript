#!/usr/bin/env escript
%% Probe 7: end-to-end compile time with and without the module-reachability check (patched COPY of bs_check/bs_diag).
%% usage: time.escript EBIN_DIR SRC_DIR   (SRC_DIR = a module directory such as compiler/examples/Interop)
%% EXPECTED (before run): the check adds well under 5% to a compile of a file with 4 foreign blocks (each which/1 on a
%%  LOADED module is microseconds; on an unloaded one ~0.5 ms), and compile times are dominated by parse+check+emit (milliseconds).
main([Ebin, Src]) ->
    true = code:add_patha(Ebin),
    Out = filename:join(os:getenv("TMPDIR", "/tmp"), "p7out"), ok = filelib:ensure_dir(filename:join(Out, "x")),
    _ = bsc:file_to_dir(Src, Out),                      %% warm (loads bsc modules)
    Ts = lists:sort([begin {US, _} = timer:tc(fun() -> bsc:file_to_dir(Src, Out) end), US end || _ <- lists:seq(1, 41)]),
    io:format("~s  N=41  min ~p us  median ~p us  max ~p us~n", [Ebin, hd(Ts), lists:nth(21, Ts), lists:last(Ts)]).
