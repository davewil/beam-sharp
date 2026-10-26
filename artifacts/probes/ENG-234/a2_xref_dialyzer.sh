#!/usr/bin/env bash
# (a2) Does any stock Erlang tool report the missing application BEFORE run time?
set -u; D=$(mktemp -d); cd "$D"
cat > caller.erl <<'X'
-module(caller).
-export([go/0]).
go() -> req:new([{url, "http://x"}]).
X
erlc +debug_info caller.erl
echo "## xref: three views, reported as-is"
erl -noshell -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]), {ok,_}=xref:add_directory(s,"."),
io:format("undefined_function_calls: ~p~n",[element(2,xref:analyze(s,undefined_function_calls))]),
io:format("locals_not_used/deprecated skipped~n"),
io:format("q (XC - UC) || (XU - X - B): ~p~n",[element(2,xref:q(s,"(XC - UC) || (XU - X - B)"))]),
io:format("q unresolved XU - X - B: ~p~n",[element(2,xref:q(s,"XU - X - B"))]),
halt().'
echo "## dialyzer: build a tiny PLT (erts kernel stdlib) then -Wunknown"
dialyzer --build_plt --output_plt p.plt --apps erts kernel stdlib >plt.log 2>&1; echo "plt exit=$?"
dialyzer --plt p.plt -Wunknown caller.beam 2>&1 | head -12
