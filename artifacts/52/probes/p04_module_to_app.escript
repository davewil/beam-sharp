#!/usr/bin/env escript
%% p04: can the compiler derive "which application does this foreign module belong to" from the
%% code path alone?  Three methods compared on four real layouts:
%%   stdlib/lists    versioned dir  (rebar3/OTP shape)    .../stdlib-4.3.1.3/ebin
%%   libdep          UNVERSIONED dir (mix _build shape)   .../_build/dev/lib/libdep/ebin
%%   elixir          unversioned dir (Elixir install)     .../lib/elixir/ebin
%%   acme            TWO versions side by side            acme-1.2.0, acme-1.3.0
%% run: ERL_LIBS=/usr/lib/elixir/lib:/tmp/mixdeps52b/consumer/_build/dev/lib:/tmp/fakelibs52 escript p04...
main(_) ->
    io:format("ERL_LIBS=~s~n~n", [os:getenv("ERL_LIBS")]),
    [probe(M) || M <- [lists, 'Elixir.Libdep', 'Elixir.Libdep.Extra', 'Elixir.String', acme_mod, erlang, nope]],
    io:format("~nTWO-VERSION CASE~n"),
    io:format("code:lib_dir(acme) = ~p~n", [code:lib_dir(acme)]),
    io:format("acme_mod:version() = ~p~n", [acme_mod:version()]),
    io:format("erlang:function_exported(acme_mod, only_in_130, 0) = ~p~n", [erlang:function_exported(acme_mod, only_in_130, 0)]),
    io:format("application:load(acme) -> ~p; vsn = ~p~n", [application:load(acme), application:get_key(acme, vsn)]),
    io:format("code:get_path() acme entries = ~p~n", [[P || P <- code:get_path(), string:find(P, "acme") =/= nomatch]]).
probe(M) ->
    Which = code:which(M),
    ByDir = by_dir(Which),
    ByApp = by_app_file(Which, M),
    Loaded = application:get_application(M),
    io:format("~-22w which=~s~n    dir-name heuristic: ~p~n    .app `modules` scan: ~p~n    application:get_application (nothing loaded yet): ~p~n",
              [M, io_lib:format("~p", [Which]), ByDir, ByApp, Loaded]).
by_dir(P) when is_list(P) ->
    Base = filename:basename(filename:dirname(filename:dirname(P))),
    list_to_atom(hd(string:split(Base, "-")));
by_dir(Other) -> Other.
by_app_file(P, M) when is_list(P) ->
    Ebin = filename:dirname(P),
    case filelib:wildcard(filename:join(Ebin, "*.app")) of
        [App] -> {ok, [{application, Name, Props}]} = file:consult(App),
                 {Name, vsn, proplists:get_value(vsn, Props), lists_member(M, proplists:get_value(modules, Props))};
        Other -> {apps_found, length(Other)}
    end;
by_app_file(Other, _) -> Other.
lists_member(M, L) -> {listed_in_modules, lists:member(M, L)}.
