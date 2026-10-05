#!/usr/bin/env escript
%%! -noshell
%% Asks the code server every question a compile-time "is this dependency present" check could ask.
%% Usage: codepath.escript LooseDir
main([Loose]) ->
    true = code:add_patha(Loose),                   % loosemod.beam, no application around it
    Targets = [
      {"mix-built Elixir dep",         mylib,    'Elixir.MyLib'},
      {"same dep, 2nd module",         mylib,    'Elixir.MyLib.Request'},
      {"OTP app, not loaded at boot",  crypto,   crypto},
      {"OTP app, loaded at boot",      stdlib,   ets},
      {"Elixir's own app",             elixir,   'Elixir.String'},
      {".app file only, no beam",      ghost,    ghost_mod},
      {"loose beam via -pa, no .app",  loose,    loosemod},
      {"absent",                       nosuch,   'Elixir.NoSuch'}],
    io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
    io:format("~-29s ~-8s ~-22s | ~-28s | ~-12s | ~-14s | ~-12s | ~s~n",
              ["target","app","module","code:which/1","lib_dir/1","where_is_file","get_app(M)","application:load/1 ; vsn"]),
    [row(T) || T <- Targets],
    ok.

row({Label, App, Mod}) ->
    Which = case code:which(Mod) of
                non_existing -> non_existing;
                cover_compiled -> cover_compiled;
                P when is_list(P) -> tail(P, 3) end,
    Lib   = case code:lib_dir(App) of {error, E} -> E; D -> tail(D, 1) end,
    AppF  = case code:where_is_file(atom_to_list(App) ++ ".app") of non_existing -> none; F -> tail(F, 3) end,
    GA0   = application:get_application(Mod),
    Load  = application:load(App),
    Vsn   = case application:get_key(App, vsn) of {ok, V} -> V; undefined -> undefined end,
    io:format("~-29s ~-8w ~-22w | ~-28s | ~-12s | ~-14s | ~-12w | ~s ; ~p~n",
              [Label, App, Mod, fmt(Which), fmt(Lib), fmt(AppF), GA0, ld(Load), Vsn]).

ld({error, {Why, File}}) when is_list(Why) -> io_lib:format("{error,~s: ~s}", [Why, File]);
ld(X) -> io_lib:format("~w", [X]).

fmt(A) when is_atom(A) -> atom_to_list(A);
fmt(S) -> S.
tail(Path, N) -> string:join(lists:nthtail(max(0, length(filename:split(Path)) - N), filename:split(Path)), "/").
