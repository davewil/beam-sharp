#!/bin/bash
# Probe 60/erlang: the BEAM baseline. Export is all-or-nothing; opaque/export_type are
# advisory (dialyzer only); xref can compute "who calls whom" AFTER compile.
set -e
cd "$(dirname "$0")"
W=$(mktemp -d); cp *.erl $W; cd $W
erlc +debug_info priv_mod.erl outsider.erl 2>&1 | sed 's/^/erlc: /'
echo "--- 1. any caller reaches an exported function, and forges an -opaque value (erlc silent):"
erl -noshell -pa . -eval 'io:format("~p~n",[outsider:run()]),halt().' | tee out1
grep -q '{42,{secret,1},7}' out1
echo "--- 2. xref: post-hoc module_use query over the compiled app"
erl -noshell -pa . -eval '
 {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
 {ok,_}=xref:add_directory(s,"."),
 {ok,U}=xref:analyze(s,{module_use,priv_mod}),
 io:format("modules using priv_mod: ~p~n",[U]),
 Allowed=[priv_mod,shop_orders], Bad=[M||M<-U,not lists:member(M,Allowed)],
 io:format("violations vs allow-list: ~p~n",[Bad]),
 halt(case Bad of [outsider]->0; _->1 end).' | tee out2
echo "--- 3. -deprecated: the only per-callee marker; erlc stays silent, never refuses"
cat > dep.erl <<'X'
-module(dep).
-export([f/0]).
-deprecated([{f,0,"internal"}]).
f() -> 1.
X
cat > use.erl <<'X'
-module(use).
-export([g/0]).
g() -> dep:f().
X
erlc +debug_info dep.erl use.erl 2>&1 | tee out3; test -f use.beam && echo "use.beam produced: deprecated != refused"
grep -q "deprecated" out3 && { echo "UNEXPECTED: erlc warned"; exit 1; }
echo "--- 4. xref deprecated_function_calls"
erl -noshell -pa . -eval '
 {ok,_}=xref:start(t),{ok,_}=xref:add_directory(t,"."),
 {ok,D}=xref:analyze(t,deprecated_function_calls),io:format("~p~n",[D]),halt().'
echo OK
