#!/usr/bin/env bash
# (a) Erlang module calling a function of an application that is not on the code path.
set -u; D=$(mktemp -d); cd "$D"
cat > caller.erl <<'X'
-module(caller).
-export([go/0]).
go() -> req:new([{url, "http://x"}]).
X
echo "## erlc caller.erl"; erlc caller.erl; echo "exit=$?"
echo "## run"; erl -noshell -pa . -eval 'try caller:go() catch C:R -> io:format("~p:~p~n",[C,R]) end, halt().'
echo "## xref:d(.) undefined_function_calls"
erl -noshell -eval '{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]), {ok,_}=xref:add_directory(s,"."), {ok,U}=xref:analyze(s, undefined_function_calls), io:format("~p~n",[U]), halt().'
echo "## dialyzer (no PLT, -Wunknown only on this module)"
which dialyzer >/dev/null 2>&1 && echo "dialyzer present" || echo "dialyzer NOT installed (erlang-dialyzer) - not measured"
