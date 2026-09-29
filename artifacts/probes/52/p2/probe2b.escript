#!/usr/bin/env escript
%% Probe 2b: does lib_dir/1 see an app that arrived by code:add_patha (as `-pa` or a bsc flag would), and does it need a vsn suffix?
%% EXPECTED (before run): lib_dir(myapp) -> {error,bad_name} before add_patha, "<dir>/myapp" after (dir named for the app);
%% lib_dir(bare) stays {error,bad_name} for a beam in a dir not shaped <app>/ebin;
%% lib_dir(myapp) reports the path even though no myapp.app is consulted (dir shape only).
main(_) ->
    D = filename:dirname(escript:script_name()),
    io:format("before   lib_dir(myapp) ~p~n", [code:lib_dir(myapp)]),
    true = code:add_patha(filename:join([D,"pa","myapp","ebin"])),
    io:format("after    lib_dir(myapp) ~p~n", [filename:basename(code:lib_dir(myapp))]),
    true = code:add_patha(filename:join(D,"bare")),
    io:format("bare     lib_dir(bare)  ~p   which(loosemod) found=~p~n", [code:lib_dir(bare), code:which(loosemod) =/= non_existing]),
    io:format("load     application:load(myapp) ~p~n", [application:load(myapp)]).
