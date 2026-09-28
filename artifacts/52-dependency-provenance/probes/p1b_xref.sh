#!/bin/sh
# PROBE 1b — follow-up added AFTER p1 showed xref's undefined_function_calls = [] (my p1 prediction that
# xref would report it was WRONG as run). First 1b attempt returned [] for EVERY query including XC, which
# meant the analysis saw no calls at all: xref reads abstract code, so the beam needs +debug_info.
# That is a probe bug (not a result-shaping edit): the beam is now compiled with +debug_info and ALL queries re-run.
# PREDICTION: calls into modules not in any added directory are "unknown" (UM lists them, XU lists the edge);
# undefined_function_calls may stay [] because xref can't judge functions of unknown modules.
cd "$(dirname "$0")"; W=work/p1b; rm -rf $W; mkdir -p $W; cp work/p1/caller.erl $W/; cd $W
erlc +debug_info caller.erl
erl -noshell -eval '
xref:start(s), xref:set_default(s,[{warnings,false}]),
{ok,_}=xref:add_directory(s,"."),
io:format("UM (unknown modules)=~p~n",[xref:q(s,"UM")]),
io:format("XC=~p~n",[xref:q(s,"XC")]),
io:format("XU=~p~n",[xref:q(s,"XU")]),
io:format("undefined_function_calls=~p~n",[xref:analyze(s,undefined_function_calls)]),
halt().'
