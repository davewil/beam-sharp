#!/usr/bin/env escript
%% H1: Erlang's PARSER keeps `-5` as {op,_,'-',{integer,_,5}} (in patterns AND guards) - no parser fold.
%% H2: constant arithmetic in a pattern is accepted by erl_lint (is_pattern_expr, erl_lint.erl:1880) only when it
%%     partially evaluates to a literal: `1+2` accepted, `Y+2` refused.
%% H3: a guard `X >= -5 + 1` reaches Core Erlang with the literal folded (compiler, not parser).
%% FALSIFIED if H1 shows {integer,_,-5}; H2 accepts Y+2; H3 core still contains a '+' call.
main(_) ->
  io:format("OTP ~s~n", [erlang:system_info(otp_release)]),
  P = fun(S) -> {ok, T, _} = erl_scan:string(S), {ok, F} = erl_parse:parse_form(T), F end,
  io:format("parse  f(-5) -> a.              clause head: ~p~n", [element(3, hd(element(5, P("f(-5) -> a."))))]),
  io:format("parse  f(X) when X >= -5 -> a.  guard      : ~p~n", [element(4, hd(element(5, P("f(X) when X >= -5 -> a."))))]),
  Dir = "/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57/erl",
  filelib:ensure_dir(Dir ++ "/x"),
  Try = fun(Name, Body, Opts) ->
          F = Dir ++ "/" ++ Name ++ ".erl",
          ok = file:write_file(F, "-module(" ++ Name ++ ").\n-export([f/1]).\n" ++ Body ++ "\n"),
          compile:file(F, [return, {outdir, Dir}] ++ Opts) end,
  Show = fun({ok, _, _})        -> accepted;
            ({ok, _, _, W})     -> {accepted, warnings, W};
            ({error, E, _})     -> {refused, [Er || {_, L} <- E, Er <- L]};
            (Other)             -> Other end,
  [io:format("compile ~-44s ~p~n", [Body, Show(Try(N, Body, []))]) ||
     {N, Body} <- [{"p1", "f(1+2) -> a."}, {"p2", "f(-5) -> a."}, {"p3", "f(Y+2) -> a."},
                   {"p4", "f(1 - -2) -> a."}, {"p5", "f(7 div 2) -> a."}, {"p6", "f(1 div 0) -> a."}]],
  Core = fun(Body) ->
           {ok, _, C} = compile:file(Dir ++ "/core.erl", [binary, to_core, no_copt_ssa] ++ []), C, Body end,
  ok = file:write_file(Dir ++ "/core.erl", "-module(core).\n-export([f/1]).\nf(X) when X >= -5 + 1 -> a;\nf(_) -> b.\n"),
  {ok, _, C} = compile:file(Dir ++ "/core.erl", [binary, to_core, return]),
  CoreTxt = lists:flatten(core_pp:format(C)),
  io:format("core of  f(X) when X >= -5 + 1:~n~s~n", [string:trim(CoreTxt)]),
  _ = Core,
  ok.
