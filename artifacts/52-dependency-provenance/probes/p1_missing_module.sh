#!/bin/sh
# PROBE 1 (i) — failure mode today: an Erlang module calls a module that is not on the path.
# PREDICTION (written before running): erlc compiles it WITHOUT any error or warning, because a remote
# call to an unknown module is not checkable by the compiler; at run time the call raises
# error:undef with a stack whose top frame is {'Elixir.Req',new,[Args],[]} (the callee) followed by the caller.
# Also predicted: `erlc +warn_missing...` has no such option; xref (a separate tool) WOULD report it.
cd "$(dirname "$0")"; W=work/p1; rm -rf $W; mkdir -p $W; cd $W
cat > caller.erl <<'EOS'
-module(caller).
-export([go/0]).
go() -> 'Elixir.Req':new([{url, <<"x">>}]).
EOS
echo "== erlc caller.erl (exit code follows)"; erlc caller.erl; echo "exit=$?"
echo "== run with ERL_LIBS unset"; env -u ERL_LIBS erl -noshell -pa . -eval 'try caller:go() catch C:R:S -> io:format("~p:~p~nstack=~p~n",[C,R,S]) end, halt().'
echo "== erlc -Wall"; erlc -Wall caller.erl; echo "exit=$?"
echo "== xref (separate tool) on the beam"
erl -noshell -eval '
xref:start(s), xref:set_default(s,[{warnings,false}]),
{ok,_}=xref:add_directory(s,"."),
{ok,U}=xref:analyze(s,undefined_function_calls),
io:format("undefined_function_calls=~p~n",[U]), halt().'
