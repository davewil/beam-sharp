#!/usr/bin/env escript
%% Two ways to name a module's application from code:which/1, on a standard
%% layout (<lib>/<app>-vsn/ebin) and a loose -pa directory with no layout.
main([Loose]) ->
    true = code:add_patha(Loose),
    [begin
         P = code:which(M),
         ByPath = list_to_atom(hd(string:split(filename:basename(filename:dirname(filename:dirname(P))), "-"))),
         ByApp = case filelib:wildcard(filename:join(filename:dirname(P), "*.app")) of
                     [F | _] -> list_to_atom(filename:basename(F, ".app"));
                     [] -> unknown end,
         io:format("~-14s by-directory-name ~-10w by-.app-beside-beam ~w~n", [M, ByPath, ByApp])
     end || M <- [crypto, httpc, fakeerl_lib, loose_mod]].
