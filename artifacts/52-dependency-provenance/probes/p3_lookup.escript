#!/usr/bin/env escript
%% PROBE 3 (iii) — what can a compiler learn at compile time about "is application X available" vs "is module M available".
%% PREDICTIONS (written before running):
%%  P1 code:lib_dir(App) answers "on path?" for an app without loading anything: {error,bad_name} when absent, a dir when present,
%%     for versioned (app_a-1.0) AND unversioned (app_c) dirs; it does NOT need the .app file (app_d: ebin with no .app -> found by dir name),
%%     and it goes by DIRECTORY name, so libE/foo-1.0 holding bar.app answers lib_dir(foo) but not lib_dir(bar).
%%  P2 code:which(M) answers "module on path?" (path | non_existing) for modules in non-app dirs too (loose_mod) — but then no app can be derived.
%%  P3 application:load(App) needs the .app file: {error,{"no such file or directory","app_d.app"}} for app_d; cheaper checks are code:lib_dir/which.
%%  P4 two apps with the same module `shared`: code:which(shared) returns whichever app's ebin is EARLIER on the path; ERL_LIBS=A:B vs B:A flips it;
%%     the module->app parse therefore answers "app_a" or "app_b" depending on ordering (ambiguity is invisible to code:which).
%%  P5 cost: code:which and code:lib_dir are tens of microseconds on a ~40-entry path (they stat directories); .app scanning of the whole path costs
%%     ~ms; application:load of a small app is ~100us.
main(_) ->
  Cwd = element(2, file:get_cwd()),
  Rel = fun(P) when is_list(P) -> string:replace(P, Cwd ++ "/", "", all); (X) -> X end,
  RelL = fun(X) -> iolist_to_binary(Rel(X)) end,
  io:format("== ERL_LIBS=~p~n", [[RelL(X) || X <- string:lexemes(os:getenv("ERL_LIBS","")++"", ":")]]),
  %% loose dir is only reachable via explicit path (ERL_LIBS scans lib dirs, not bare beams)
  true = code:add_pathz(Cwd ++ "/loose"),
  io:format("-- Q1 code:lib_dir(App) (no loading)~n"),
  [io:format("  lib_dir(~w) = ~p~n", [A, case code:lib_dir(A) of {error,E} -> {error,E}; D -> RelL(D) end])
     || A <- [stdlib, app_a, app_b, app_c, app_d, foo, bar, req, no_such_app]],
  io:format("-- Q2 code:which(Mod)~n"),
  [io:format("  which(~w) = ~p~n", [M, case code:which(M) of W when is_list(W) -> RelL(W); W -> W end])
     || M <- [lists, a_mod, b_mod, c_mod, d_mod, loose_mod, e_mod, shared, 'Elixir.Req', no_such_mod]],
  io:format("-- Q3 application:load(App)  (needs .app; side effect: registers app in the app controller)~n"),
  [io:format("  load(~w) = ~p~n", [A, application:load(A)]) || A <- [app_a, app_d, bar, foo, no_such_app]],
  io:format("  get_key(app_b,applications) after load = ~p~n", [begin application:load(app_b), application:get_key(app_b, applications) end]),
  io:format("-- Q4 module->app via which+parse vs via scanning .app files~n"),
  [io:format("  ~w: parse=~p scan=~p~n", [M, mod_to_app_parse(M), mod_to_app_scan(M)]) || M <- [lists, a_mod, d_mod, loose_mod, e_mod, shared, no_such_mod]],
  io:format("-- Q5 cost, microseconds per call (mean of N runs, path length = ~w)~n", [length(code:get_path())]),
  Bench = fun(Name, N, F) ->
      {T, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, N)] end),
      io:format("  ~-44s ~8.2f us/call (N=~w)~n", [Name, T / N, N]) end,
  Bench("code:which(lists) [hit, OTP]", 2000, fun() -> code:which(lists) end),
  Bench("code:which(no_such_mod) [miss, full path scan]", 2000, fun() -> code:which(no_such_mod) end),
  Bench("code:lib_dir(stdlib) [hit]", 2000, fun() -> code:lib_dir(stdlib) end),
  Bench("code:lib_dir(app_c) [hit, unversioned]", 2000, fun() -> code:lib_dir(app_c) end),
  Bench("code:lib_dir(no_such_app) [miss]", 2000, fun() -> code:lib_dir(no_such_app) end),
  Bench("code:where_is_file(\"app_c.app\")", 2000, fun() -> code:where_is_file("app_c.app") end),
  Bench("mod_to_app_parse(a_mod)", 2000, fun() -> mod_to_app_parse(a_mod) end),
  Bench("mod_to_app_scan(a_mod) [reads every .app on path]", 50, fun() -> mod_to_app_scan(a_mod) end),
  Bench("mod_to_app_scan(no_such_mod) [full scan, miss]", 50, fun() -> mod_to_app_scan(no_such_mod) end),
  Bench("application:load(app_c) first (cold)", 1, fun() -> application:load(app_c) end),
  Bench("application:load(app_c) again", 2000, fun() -> application:load(app_c) end),
  {TE, _} = timer:tc(fun() -> code:ensure_loaded(c_mod) end),
  io:format("  code:ensure_loaded(c_mod) first (loads the beam)      ~8w us (N=1)~n", [TE]).

%% which -> <root>/<app>[-vsn]/ebin/<mod>.beam ; app = basename of the dir two levels up, vsn stripped
mod_to_app_parse(M) ->
  case code:which(M) of
    P when is_list(P) ->
      Ebin = filename:dirname(P),
      case filename:basename(Ebin) of
        "ebin" -> App = filename:basename(filename:dirname(Ebin)),
                  list_to_atom(hd(string:split(App, "-")));
        _ -> {not_in_an_ebin, filename:basename(Ebin)}
      end;
    Other -> Other
  end.
%% every *.app in every path dir; the app whose `modules` contains M (all of them, in path order)
mod_to_app_scan(M) ->
  Hits = [A || D <- code:get_path(), F <- filelib:wildcard(filename:join(D, "*.app")),
               {ok, [{application, A, Kv}]} <- [file:consult(F)],
               lists:member(M, proplists:get_value(modules, Kv, []))],
  Hits.
