#!/usr/bin/env bash
# Ticket 57 survey. Where does each neighbour fold `-5`: the parser, or a later pass?
. "$(dirname "$0")/../env.sh"
echo '--- Erlang: erl_parse of "-5." (expect a unary-op node, NOT {integer,_,-5})'
erl -noshell -eval '{ok,T,_}=erl_scan:string("-5."), {ok,[E]}=erl_parse:parse_exprs(T), io:format("~p~n",[E]), halt().'
echo '--- Erlang: erl_lint:is_pattern_expr on that node (the linter folds it)'
erl -noshell -eval '{ok,T,_}=erl_scan:string("-5."), {ok,[E]}=erl_parse:parse_exprs(T), io:format("~p~n",[erl_lint:is_pattern_expr(E)]), halt().'
echo '--- Erlang: a guard that compares against a negative literal compiles, and the BEAM code has the folded constant'
W=$(mktemp -d); cat > $W/g.erl <<'X'
-module(g).
-export([f/1]).
f(N) when N >= -5 -> a;
f(_) -> b.
X
erlc -S -o $W $W/g.erl && grep -n "is_ge\|{integer,-5}\|-5" $W/g.S | head -4
echo '--- Elixir: Code.string_to_quoted("-5") (expect a unary-op AST, folded later)'
elixir -e 'IO.inspect(Code.string_to_quoted!("-5")); IO.inspect(Code.string_to_quoted!("x >= -5"))' 2>&1 | grep -v warning
echo '--- Elixir: negative literal in a guard and a pattern'
elixir -e 'defmodule G do
  def f(n) when n >= -5, do: :a
  def f(_), do: :b
  def g(-1), do: :neg1
  def g(_), do: :other
end
IO.inspect({G.f(-6), G.f(-5), G.g(-1)})' 2>&1 | grep -v warning
echo '--- Gleam: negative literal in a pattern and a guard'
G=$(mktemp -d); (cd $G && mkdir -p src && printf 'name = "p"\nversion = "1.0.0"\n' > gleam.toml && cat > src/p.gleam <<'X'
pub fn f(n: Int) -> Int {
  case n {
    x if x >= -5 -> 1
    _ -> 0
  }
}
pub fn g(n: Int) -> Int {
  case n {
    -1 -> 1
    _ -> 0
  }
}
X
gleam build 2>&1 | tail -3; echo "gleam rc=$?")
