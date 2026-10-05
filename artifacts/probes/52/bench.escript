#!/usr/bin/env escript
%%! -noshell
main(_) ->
    N = 20000,
    io:format("code path entries: ~p~n", [length(code:get_path())]),
    T = fun(Label, F) ->
            {US, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, N)], ok end),
            io:format("~-48s ~8.3f us/call  (N=~p)~n", [Label, US / N, N])
        end,
    T("code:lib_dir(mylib)            hit",  fun() -> code:lib_dir(mylib) end),
    T("code:lib_dir(nosuch)           miss", fun() -> code:lib_dir(nosuch) end),
    T("code:which('Elixir.MyLib')     hit",  fun() -> code:which('Elixir.MyLib') end),
    T("code:which('Elixir.NoSuch')    miss", fun() -> code:which('Elixir.NoSuch') end),
    M = 300,
    {WUS, _} = timer:tc(fun() -> [code:where_is_file("mylib.app") || _ <- lists:seq(1, M)], ok end),
    io:format("~-48s ~8.3f us/call  (N=~p)~n", ["code:where_is_file(\"mylib.app\") hit (scans path)", WUS / M, M]),
    {WMS, _} = timer:tc(fun() -> [code:where_is_file("nosuch.app") || _ <- lists:seq(1, M)], ok end),
    io:format("~-48s ~8.3f us/call  (N=~p)~n", ["code:where_is_file(\"nosuch.app\") miss (scans path)", WMS / M, M]),
    K = 300,
    {LUS, _} = timer:tc(fun() -> [begin application:load(mylib), application:unload(mylib) end || _ <- lists:seq(1, K)], ok end),
    io:format("~-48s ~8.3f us/call  (N=~p)~n", ["application:load+unload(mylib) (reads+parses .app)", LUS / K, K]).
