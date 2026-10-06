#!/usr/bin/env bash
# 57c: Claim: Erlang and Elixir do NOT fold `-5` in the grammar -- both parse it as a unary-minus
# node over the literal and leave the fold to consumers (erl_parse:normalise, erl_eval:partial_eval,
# pattern/guard/typespec checks). Control: `0-5` parses as a DIFFERENT node (binary op), so the
# parser does distinguish the two spellings -- if it folded, both would print as {integer,_,-5}.
# Also tests that downstream they all accept the negative bound (pattern, guard, range type).
# Run with scratchpad env.sh sourced (erl, elixir on PATH).
set -u
echo "== Erlang: erl_parse:parse_exprs =="
erl -noshell -eval '
  P = fun(S) -> {ok,T,_} = erl_scan:string(S), {ok,E} = erl_parse:parse_exprs(T), io:format("  ~-10s ~p~n",[S,[erl_parse:map_anno(fun(_)->0 end,X)||X<-E]]) end,
  [P(S) || S <- ["-5.", "0-5.", "- -5.", "-(5).", "2+3.", "X >= -5."]],
  {ok,T,_} = erl_scan:string("-5."), {ok,[E5]} = erl_parse:parse_exprs(T),
  io:format("  erl_parse:normalise(-5 node)   = ~p~n",[erl_parse:normalise(E5)]),
  io:format("  erl_eval:partial_eval(-5 node) = ~p~n",[erl_eval:partial_eval(E5)]),
  {ok,T2,_} = erl_scan:string("2+3."), {ok,[E23]} = erl_parse:parse_exprs(T2),
  io:format("  erl_eval:partial_eval(2+3)     = ~p~n",[erl_eval:partial_eval(E23)]),
  io:format("  erl_lint:is_pattern_expr(-5)   = ~p~n  erl_lint:is_pattern_expr(2+3) = ~p~n  erl_lint:is_pattern_expr(X-5) = ~p~n",
     [erl_lint:is_pattern_expr(E5), erl_lint:is_pattern_expr(E23), begin {ok,T3,_}=erl_scan:string("X-5."),{ok,[E3]}=erl_parse:parse_exprs(T3),erl_lint:is_pattern_expr(E3) end]),
  halt().'
echo "== Erlang: compile a module with -5 in pattern, guard, type range; 2+3 in a pattern; a var in a pattern arithmetic =="
d=$(mktemp -d)
cat > "$d/neg.erl" <<'EOT'
-module(neg).
-export([f/1, g/1, h/1]).
-type t() :: -5..5.
-spec f(integer()) -> atom().
f(-5) -> a;
f(2+3) -> b;
f(_) -> c.
g(X) when X >= -5 -> yes;
g(_) -> no.
-spec h(t()) -> t().
h(X) -> X.
EOT
erlc -o "$d" "$d/neg.erl" && echo "  neg.erl compiled: f(-5)=$(erl -noshell -pa "$d" -eval 'io:format("~p ~p ~p",[neg:f(-5),neg:f(5),neg:g(-3)]),halt().')"
cat > "$d/bad.erl" <<'EOT'
-module(bad).
-export([f/2]).
f(X, N) when X >= N - 5 -> ok;
f(_, _) -> no.
f2(X, N) -> case X of N - 5 -> ok end.
EOT
echo "  control (must be an ERROR: arithmetic with a variable in a PATTERN is not constant):"
erlc -o "$d" "$d/bad.erl" 2>&1 | sed "s#$d/##" | head -3
echo "== Elixir: Code.string_to_quoted =="
elixir -e '
  for s <- ["-5", "0 - 5", "- -5", "-(5)", "2 + 3", "x >= -5"] do
    IO.puts("  " <> String.pad_trailing(s, 8) <> inspect(Code.string_to_quoted!(s), charlists: :as_lists))
  end
  # control: the compiled behaviour -- pattern and guard accept negative literals, expression with var in pattern does not
  defmodule N do
    def f(-5), do: :a
    def f(x) when x >= -5, do: :b
    def f(_), do: :c
  end
  IO.inspect({N.f(-5), N.f(0), N.f(-9)}, label: "  N.f(-5), N.f(0), N.f(-9)")
  try do
    Code.eval_string("defmodule M2 do\n def f(x, n), do: (case x do n - 5 -> :ok end)\nend")
  rescue e -> IO.puts("  control (must error) pattern `n - 5`: " <> String.slice(Exception.message(e), 0, 90))
  end
'
