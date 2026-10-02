#!/usr/bin/env bash
# P1: a module calling a remote module that is absent from the code path.
# Claims: erlc is silent; run time is error:undef; the .beam's imports chunk
# ALREADY records the remote MFA; xref flags it only when asked.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"; cd "$W" || exit 2
fail=0
echo "== erlc -Wall +debug_info (bsc also passes debug_info, bsc.erl build/3) on a call to 'Elixir.Req':new/1 (absent) =="
out=$(erlc -Wall +debug_info "$D/src/uses_missing.erl" 2>&1); echo "exit=$? output=[${out}]"
[ -z "$out" ] || { echo "UNEXPECTED: erlc spoke"; fail=1; }
echo "== run it =="
r=$(erl -noshell -pa . -eval 'try uses_missing:go() catch C:R -> io:format("~p:~p~n",[C,R]) end, halt().')
echo "$r"; case "$r" in error:undef*) ;; *) echo "UNEXPECTED"; fail=1;; esac
echo "== beam_lib imports chunk (what the beam itself already says) =="
i=$(erl -noshell -eval '{ok,{_,[{imports,I}]}}=beam_lib:chunks("uses_missing.beam",[imports]), io:format("~p~n",[I]), halt().')
echo "$i"; case "$i" in *"Elixir.Req"*) ;; *) echo "UNEXPECTED"; fail=1;; esac
echo "== xref undefined_function_calls =="
x=$(erl -noshell -eval '{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]), {ok,_}=xref:add_directory(s,"."), {ok,U}=xref:analyze(s,undefined_function_calls), io:format("~p~n",[U]), halt().')
echo "$x"; case "$x" in *"Elixir.Req"*) ;; *) echo "UNEXPECTED"; fail=1;; esac
echo "== does a stock .beam name its application? attributes of lists.beam and gen_server.beam =="
erl -noshell -eval '[io:format("~p ~p~n",[M,M:module_info(attributes)]) || M <- [lists,gen_server]], halt().'
a=$(erl -noshell -eval 'io:format("~p",[[K || M <- [lists,gen_server,uses_missing], {K,_} <- M:module_info(attributes), lists:member(K,[app,application,applications,otp_app,required_app])]]), halt().' -pa .)
echo "attribute keys naming an application: $a"; [ "$a" = "[]" ] || { echo UNEXPECTED; fail=1; }
rm -rf "${W:?}"; exit $fail
