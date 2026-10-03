#!/usr/bin/env escript
%% module->app by directory name: code:which gives <dir>/<app>[-vsn]/ebin/Mod.beam
main(_) ->
    [begin
         P = code:which(M),
         Ebin = filename:dirname(P),
         AppDir = filename:basename(filename:dirname(Ebin)),
         io:format("~-16w ~s -> appdir ~s~n", [M, P, AppDir])
     end || M <- ['Elixir.String','Elixir.EEx','lists']].
