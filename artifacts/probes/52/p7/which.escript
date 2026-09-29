#!/usr/bin/env escript
%% Probe 7b: cost of the reachability test itself, in a FRESH VM, as bsc would call it (first call, then repeated).
%% EXPECTED (before run): the first code:which/1 on a not-yet-loaded module costs ~0.5 ms (path scan, matches probe 2);
%%  on a loaded or preloaded module it is single-digit microseconds; so a file with 3 OTP foreign blocks pays ~microseconds
%%  to a few ms in total, i.e. a small fraction of a ~20 ms compile.
main(_) ->
    First = fun(M) -> {US, R} = timer:tc(fun() -> code:which(M) end),
                      io:format("first which(~-8w) ~7w us  found=~p~n", [M, US, element(1, {R =/= non_existing})]) end,
    [First(M) || M <- [erlang, lists, ets, maps, file, sofs, zip, xmerl_scan]],
    {US2, _} = timer:tc(fun() -> [code:which(M) || M <- [erlang, lists, ets, maps, file, sofs, zip, xmerl_scan]] end),
    io:format("second pass over the same 8: ~p us total~n", [US2]).
