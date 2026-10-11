#!/usr/bin/env escript
%% Probe (b): which presence test is right for which kind of dependency?
%% Run via p2_presence.sh (sets ERL_LIBS and -pa).
-define(CASES, [
  %% {label, App, Module}
  {"erlang app + its module",              stdlib,    lists},
  {"elixir stdlib: String lives in app 'elixir'", elixir, 'Elixir.String'},
  {"mix app on ERL_LIBS",                  exdep,     'Elixir.ExDep'},
  {"erlc app on ERL_LIBS",                 erldep,    erldep},
  {"WRONG app name, right module (ex_dep)",ex_dep,    'Elixir.ExDep'},
  {"app name guessed from module (string) for Elixir.String", string, 'Elixir.String'},
  {"module on -pa, in NO app",             orphanmod, orphanmod},
  {"ebin dir w/o .app on ERL_LIBS",        noappfile, noappmod},
  {".app says modules=[] but beam present",bareapp,   bareapp},
  {".app lists a module whose beam is absent", ghostapp, ghostmod},
  {"dir 'dirname_mismatch' holds app 'realname': ask by APP name", realname, realname},
  {"...ask by DIR name",                   dirname_mismatch, realname},
  {"orphan: ask lib_dir by the parent DIR name 'orphan'", orphan, orphanmod},
  {"nothing at all",                       nosuchapp, nosuchmod},
  {"preloaded module (erlang) / app erts", erts,      erlang}
]).

main([]) ->
  io:format("code path entries mentioning FX: ~p~n",
            [[filename:basename(filename:dirname(P)) || P <- code:get_path(), string:find(P, "_fx") =/= nomatch]]),
  [row(C) || C <- ?CASES],
  inmem(),
  ok.

short(P) when is_list(P) ->
  case string:find(P, "_fx/") of
    nomatch -> case string:find(P, "/lib/") of nomatch -> P; S -> lists:flatten(["..", S]) end;
    S -> lists:flatten(string:replace(S, "ebin/", "ebin/", all))
  end;
short(X) -> lists:flatten(io_lib:format("~w", [X])).

row({Label, App, Mod}) ->
  LD = code:lib_dir(App),
  W = code:which(Mod),
  AL = case application:load(App) of ok -> ok; {error,{already_loaded,_}} -> already_loaded; {error,{E,_}} when is_list(E) -> {err,E}; Other -> Other end,
  Key = case application:get_key(App, modules) of {ok, Ms} -> lists:member(Mod, Ms); undefined -> n_a end,
  AF = code:where_is_file(atom_to_list(App) ++ ".app"),
  io:format("~s~n    app=~w  lib_dir=~s~n    which=~s~n    where_is_file(App.app)=~s~n    application:load=~s  .app-modules-lists-Mod=~w~n",
            [Label, App, short(LD), short(W), short(AF), lists:flatten(io_lib:format("~p",[AL])), Key]).

%% A module that is loaded but has no file at all, and belongs to no app.
inmem() ->
  Forms = [{attribute,1,module,inmem},{attribute,1,export,[{f,0}]},{function,1,f,0,[{clause,1,[],[],[{atom,1,ok}]}]}],
  {ok, inmem, Bin} = compile:forms(Forms),
  {module, inmem} = code:load_binary(inmem, "", Bin),
  io:format("~nloaded-from-memory module: code:which(inmem)=~p  code:is_loaded(inmem)=~p  lib_dir(inmem)=~p~n",
            [code:which(inmem), element(1, code:is_loaded(inmem)) , code:lib_dir(inmem)]).
