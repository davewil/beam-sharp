#!/usr/bin/env escript
%% p02: how can a compiler ask "is application X / module M reachable?" at compile time,
%% and what does each answer when the library IS and ISN'T on the path?
main(_) ->
    io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
    io:format("mode=~p  path entries=~p~n", [code:get_mode(), length(code:get_path())]),
    Apps = [eex, elixir, req, logger, nosuchapp],
    Mods = ['Elixir.String', 'Elixir.EEx', 'Elixir.Req', lists],
    io:format("-- code:lib_dir(App)   [path lookup by app name, no load]~n"),
    [io:format("  ~-10w ~p~n", [A, code:lib_dir(A)]) || A <- Apps],
    io:format("-- code:which(Mod)     [path lookup by module, no load]~n"),
    [io:format("  ~-16w ~p~n", [M, code:which(M)]) || M <- Mods],
    io:format("-- code:where_is_file(\"<app>.app\")~n"),
    [io:format("  ~-10w ~p~n", [A, code:where_is_file(atom_to_list(A) ++ ".app")]) || A <- Apps],
    io:format("-- application:load(App)  [reads .app, SIDE EFFECT: registers app in app controller]~n"),
    [io:format("  ~-10w ~p~n", [A, case application:load(A) of
                                    {error,{Why,_}} -> {error,Why};
                                    X -> X end]) || A <- Apps],
    io:format("-- application:get_key(eex, modules) / applications~n"),
    io:format("  ~p~n  ~p~n", [application:get_key(eex, modules), application:get_key(eex, applications)]),
    io:format("-- application:get_application(Mod)  [needs app loaded]~n"),
    [io:format("  ~-16w ~p~n", [M, application:get_application(M)]) || M <- ['Elixir.String','Elixir.EEx',lists]],
    io:format("-- erl_prim_loader:list_dir on each path entry's parent~n"),
    io:format("  ~p~n", [erl_prim_loader:list_dir("/tmp/otp/lib/elixir/lib")]),
    io:format("-- does code:lib_dir lie when only .beam is on -pa (no app dir)? see p02 run.sh part 2~n"),
    ok.
