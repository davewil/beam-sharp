#!/usr/bin/env bash
# P6: Erlang's answer to "which calls leave this app": xref (post-hoc, separate tool), over a B#-emitted beam.
# Positive: Dep.beam (calls absent Elixir.Req) -> undefined_function_calls lists it. Control: NoDep.beam -> [].
# Also shows `applications` is a SEPARATE hand-written list (rebar3 .app.src) that nothing in the beam is compared against.
. "$(dirname "$0")/../lib.sh"
D=$(mktemp -d); cd "$D"; mkdir Dep NoDep
printf 'module Dep\nusing :%s {\n    term new(list<(atom, term)> opts)\n}\npublic term Go(list<(atom, term)> o)\nGo(o) -> :%s.new(o)\n' "'Elixir.Req'" "'Elixir.Req'" > Dep/a.bs
printf 'module NoDep\npublic int Id(int x)\nId(x) -> x\n' > NoDep/a.bs
bsc -o out Dep/a.bs; bsc -o out NoDep/a.bs
erl -noshell -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
{ok,_}=xref:add_directory(s,"out"),
{ok,U}=xref:analyze(s,undefined_function_calls),
io:format("undefined_function_calls = ~p~n",[U]),
{ok,A}=xref:analyze(s,{module_call,'"'"'Dep'"'"'}), io:format("modules Dep calls = ~p~n",[A]),
halt().'
echo "--- control: NoDep.beam alone (expect [])"
mkdir ctl; cp out/NoDep.beam ctl/
erl -noshell -eval '{ok,_}=xref:start(c), xref:set_default(c,[{warnings,false}]), {ok,_}=xref:add_directory(c,"ctl"), {ok,U}=xref:analyze(c,undefined_function_calls), io:format("undefined_function_calls = ~p~n",[U]), halt().'
echo "--- the app-level list lives in a hand-written file: ssl.app line 85 (installed OTP 25)"
sed -n 85p /usr/lib/erlang/lib/ssl-*/ebin/ssl.app
