#!/usr/bin/env escript
%% Probe 2: cheap answers to "is application X / module M reachable on the code path?"
%% EXPECTED (stated before the run):
%%  E1 code:lib_dir(elixir)  -> {error,bad_name} when ERL_LIBS unset; a path when ERL_LIBS=/usr/lib/elixir/lib
%%  E2 code:lib_dir(nope)    -> {error,bad_name}
%%  E3 code:which('Elixir.Enum') -> non_existing unset; a .beam path with ERL_LIBS
%%  E4 code:which(loosemod) after code:add_patha(loose) -> a path, but code:lib_dir(loosemod) -> {error,bad_name}
%%     (a module-only beam is visible to which/1 and invisible to lib_dir/1)
%%  E5 application:load(elixir) -> ok with ERL_LIBS, {error,{"no such file or directory","elixir.app"}} without
%%  E6 timing: lib_dir is a table lookup, single-digit microseconds; which/1 and where_is_file/1 on an
%%     unloaded module scan the path, so they are 100x or more slower per call than lib_dir/1.
main(_) ->
    N = 20000,
    io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
    row("lib_dir(elixir)", code:lib_dir(elixir)),
    row("lib_dir(nope)", code:lib_dir(nope)),
    row("lib_dir(stdlib) [control]", element(1, {code:lib_dir(stdlib) =/= {error,bad_name}})),
    row("which('Elixir.Enum')", code:which('Elixir.Enum')),
    row("which('Elixir.Nope')", code:which('Elixir.Nope')),
    row("which(erlang) [preloaded]", code:which(erlang)),
    row("which(lists)", code:which(lists)),
    true = code:add_patha(filename:join(filename:dirname(escript:script_name()), "loose")),
    row("which(loosemod) after add_patha", filename:basename(code:which(loosemod))),
    row("lib_dir(loosemod)", code:lib_dir(loosemod)),
    row("where_is_file(\"elixir.app\")", code:where_is_file("elixir.app")),
    %% timing: min and median of 7 batches of N calls, microseconds per call
    T2 = fun(Name, F, M) ->
            Xs = lists:sort([begin {US,_} = timer:tc(fun() -> loop(M, F) end), US / M end || _ <- lists:seq(1,7)]),
            io:format("TIME ~-34s min ~9.3f us  median ~9.3f us  (N=~p x 7)~n",
                      [Name, hd(Xs), lists:nth(4, Xs), M])
        end,
    T = fun(Name, F) -> T2(Name, F, N) end,
    T("lib_dir(elixir)", fun() -> code:lib_dir(elixir) end),
    T("lib_dir(nope)", fun() -> code:lib_dir(nope) end),
    T2("which('Elixir.Enum') unloaded", fun() -> code:which('Elixir.Enum') end, 200),
    T2("which('Elixir.Nope') miss", fun() -> code:which('Elixir.Nope') end, 200),
    T2("where_is_file(elixir.app)", fun() -> code:where_is_file("elixir.app") end, 200),
    T("is_loaded(Elixir.Enum)", fun() -> code:is_loaded('Elixir.Enum') end),
    %% application:load has a side effect (loads the app spec once); time the repeat call and a fresh miss
    row("application:load(elixir)", application:load(elixir)),
    row("application:load(elixir) again", application:load(elixir)),
    row("application:load(nope)", application:load(nope)),
    T2("application:load(nope) miss", fun() -> application:load(nope) end, 200),
    T("application:load(elixir) already", fun() -> application:load(elixir) end),
    row("ebin count on path", length(code:get_path())).
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N-1, F).
row(L, V) -> io:format("~-34s ~p~n", [L, V]).
