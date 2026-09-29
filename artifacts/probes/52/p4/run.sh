#!/usr/bin/env bash
# Probe 4: Erlang's own precedent (OTP 25).
# EXPECTED (stated before the run):
#  4a erlc on a call to a module that exists nowhere: exit 0, no warning (erlc checks no remote calls).
#  4b erlc on `-required_app(nope_app).`: exit 0, no warning (an unknown attribute is just stored in the beam's attributes).
#  4c (with +debug_info; without it xref sees nothing, discovered on first run) xref (analysis undefined_function_calls) over ebin/ reports {caller,f,0} -> {'Elixir.Nope',count,1}: a whole-program check AFTER compile, not in erlc.
#  4d an .app whose `applications` names a missing app: application:load/1 succeeds (the list is not checked at load),
#     application:ensure_all_started/1 fails {error,{nope_app,{"no such file or directory","nope_app.app"}}}; and
#     systools:make_script on a rel naming myapp reports the missing app before producing a script.
here=$(cd "$(dirname "$0")" && pwd); cd "$here"
rm -rf ebin/* rel/*
echo "=== 4a/4b erlc (plain, no debug_info)"; erlc -o ebin src/caller.erl; echo "erlc exit=$?"
echo "=== 4c prelude: xref on this beam WITHOUT debug_info"
erl -noshell -pa ebin -eval '{ok,_}=xref:start(s0), R=xref:add_directory(s0,"ebin"), io:format("~p~n",[R]), {ok,U}=xref:analyze(s0,undefined_function_calls), io:format("undefined_function_calls (no debug_info): ~p~n",[U]), halt().'
echo "=== 4c recompile with +debug_info (xref reads the abstract code; first attempt without it returned [] and was a setup error, not a finding)"
erlc +debug_info -o ebin src/caller.erl
echo "=== 4b attribute survives in the beam:"; erl -noshell -eval 'io:format("~p~n",[proplists:get_value(required_app, caller:module_info(attributes))])' -pa ebin -eval 'halt().' 2>&1
echo "=== 4c xref"
erl -noshell -pa ebin -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
  {ok,_}=xref:add_directory(s,"ebin"),
  {ok,U}=xref:analyze(s,undefined_function_calls), io:format("~p~n",[U]), halt().'
echo "=== 4d .app applications list"
sed 's/{vsn,/{description,"probe"},{vsn,/' src/myapp.app.src > ebin/myapp.app
erl -noshell -pa ebin -eval '
  io:format("load: ~p~n",[application:load(myapp)]),
  io:format("ensure_all_started: ~p~n",[application:ensure_all_started(myapp)]),
  halt().'
echo "=== 4d systools:make_script"
echo '{release,{"r","1"},{erts,"13.2.2.5"},[{kernel,"8.5.4.2"},{stdlib,"4.3.1.3"},{myapp,"0.1.0"}]}.' > rel/r.rel
erl -noshell -pa ebin -eval '
  R = systools:make_script("rel/r", [silent,{path,["ebin"]},local]),
  io:format("~p~n",[R]), halt().'
