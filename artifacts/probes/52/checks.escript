#!/usr/bin/env escript
%% What each cheap check says for {Module, App} pairs, in this VM's ERL_LIBS.
%% Cases: Elixir-style app, rebar3 app, module in OTP, module in erts, preloaded, missing.
main(_) ->
    io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
    Cases = [{'Elixir.Fakeel', fakeel,   "Elixir-style app (mix)"},
             {fakeerl_lib,     fakeerl,  "rebar3 app"},
             {'Elixir.String', elixir,   "Elixir stdlib"},
             {crypto,          crypto,   "OTP app, NIF"},
             {httpc,           inets,    "OTP: module name /= app name"},
             {lists,           stdlib,   "OTP stdlib"},
             {ets,             erts,     "ets: a module one might assume lives in erts"},
             {erlang,          erts,     "preloaded"},
             {no_such_mod,     no_such_app, "missing"}],
    [row(M, A, D) || {M, A, D} <- Cases].

row(M, A, D) ->
    Which = code:which(M),
    LibDir = case code:lib_dir(A) of {error, E} -> {error, E}; P -> short(P) end,
    %% application:load reads <lib>/ebin/<app>.app; it does NOT start anything.
    Load = application:load(A),
    Loaded = erlang:module_loaded(M),
    Ens = code:ensure_loaded(M),
    io:format("~n[~s]  module ~p  app ~p~n", [D, M, A]),
    io:format("  code:which(M)            = ~p~n", [short(Which)]),
    io:format("  code:lib_dir(A)          = ~p~n", [LibDir]),
    io:format("  application:load(A)      = ~p~n", [Load]),
    io:format("  module_loaded before ens = ~p~n", [Loaded]),
    io:format("  code:ensure_loaded(M)    = ~p~n", [Ens]),
    io:format("  app owning M (get_application, after load/ensure) = ~p~n", [application:get_application(M)]).

short(P) when is_list(P) ->
    case string:prefix(P, code:root_dir()) of
        nomatch -> case string:prefix(P, os:getenv("WORK")) of nomatch -> P; R -> lists:flatten("$WORK" ++ R) end;
        R -> lists:flatten("$OTP" ++ R)
    end;
short(X) -> X.
