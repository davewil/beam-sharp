#!/usr/bin/env bash
# How Erlang and Elixir treat a negative literal at parse time, in patterns, guards.
source /tmp/claude-0/env.sh
W=$(mktemp -d)
echo "--- Erlang: parse tree of -5 and 2+3 in guard & pattern (erl_parse keeps a unary op node)"
erl -noshell -eval '
{ok,T,_}=erl_scan:string("f(X) when X >= -5 -> 2+3."),
{ok,F}=erl_parse:parse_form(T), io:format("~p~n",[F]),
{ok,T2,_}=erl_scan:string("f(-5) -> a."), {ok,F2}=erl_parse:parse_form(T2), io:format("~p~n",[F2]),
halt().'
echo "--- Erlang: compile pattern f(-1), f(1+2), guard X >= -5, X >= 2+3, and a non-constant comparand in a guard"
cat > $W/e.erl <<'EOS'
-module(e).
-export([a/1,b/1,c/1,d/2]).
a(-1) -> neg; a(_) -> other.
b(1+2) -> three; b(_) -> other.
c(X) when X >= -5, X =< 2+3 -> in; c(_) -> out.
d(X, N) when X >= N -> ge; d(_, _) -> lt.
EOS
(cd $W && erlc e.erl && echo "erlc rc=0" && erl -noshell -pa . -eval 'io:format("~p ~p ~p ~p~n",[e:a(-1),e:b(3),e:c(-5),e:d(1,0)]),halt().')
echo "--- Erlang abstract tree after erl_lint partial_eval: -1 in pattern stays {op,_,-,{integer,_,1}} in abstract form; core:"
(cd $W && erlc +dcore e.erl && grep -n "\-1\|-5" e.core | head -5)
echo "--- Elixir: Code.string_to_quoted of -5, and guard/pattern use"
elixir -e '
IO.inspect(Code.string_to_quoted!("-5"))
IO.inspect(Code.string_to_quoted!("x >= -5"))
defmodule E do
  def a(-1), do: :neg
  def a(_), do: :other
  def c(x) when x >= -5 and x <= 2 + 3, do: :in
  def c(_), do: :out
end
IO.inspect({E.a(-1), E.c(-5), E.c(6)})
'
