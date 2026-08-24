#!/usr/bin/env bash
# PROTOTYPE 48a — what `:=` and `=>` actually mean, in Erlang and in Elixir.
#
# Throwaway. Ticket 48, the Erlang/Elixir arm of the borrow survey.
#
# Ticket 48's survey stub says: "matchable, and the `%{k := v}` / `%{k => v}`
# distinction between 'must be present' and 'may be' is a form beam-sharp has
# no equivalent of."
#
# That sentence is a CLAIM, and this script exists to check it before the
# grilling reasons from it. Four questions, each one compiled or run rather
# than read:
#
#   1. Is `=>` legal in an Erlang map PATTERN, or only `:=`?
#   2. Does `:=` exist in an Elixir map pattern, or only `=>`?
#   3. In an Erlang UPDATE, what separates `M#{k := V}` from `M#{k => V}`?
#   4. Can either language's pattern form say a key is ABSENT?
#
#   ./48a_map_forms_erlang_elixir.sh
#
# Requires: OTP 28, Elixir. Runs entirely in a temp dir — nothing is written
# to the repo, and nothing here touches bsc.
set -uo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1

# Compile one Erlang module and report whether erlc accepted it. The error
# text is the evidence, so it is printed verbatim and never summarised.
erl_probe () {
    local name="$1" body="$2"
    printf '%s\n' "$body" > "$WORK/$name.erl"
    echo "--- $name ---"
    if erlc -o "$WORK" "$WORK/$name.erl" 2>&1; then
        echo "    COMPILES"
    else
        echo "    REFUSED (text above)"
    fi
    echo
}

# Evaluate an Elixir snippet, printing whatever comes back — value or error.
ex_probe () {
    local label="$1" code="$2"
    echo "--- $label ---"
    elixir -e "$code" 2>&1 | sed 's/^/    /'
    echo
}

echo "==============================================================="
echo "1. Erlang PATTERN position: is => legal, or only := ?"
echo "==============================================================="

erl_probe p_pattern_exact '
-module(p_pattern_exact).
-export([f/1]).
f(#{k := V}) -> V.
'

erl_probe p_pattern_assoc '
-module(p_pattern_assoc).
-export([f/1]).
f(#{k => V}) -> V.
'

echo "==============================================================="
echo "2. Erlang CONSTRUCTION position: is := legal on a fresh literal?"
echo "==============================================================="

erl_probe p_build_assoc '
-module(p_build_assoc).
-export([f/1]).
f(V) -> #{k => V}.
'

erl_probe p_build_exact '
-module(p_build_exact).
-export([f/1]).
f(V) -> #{k := V}.
'

echo "==============================================================="
echo "3. Erlang UPDATE position: what separates := from => at RUNTIME?"
echo "==============================================================="

erl_probe p_update '
-module(p_update).
-export([exact/2, assoc/2, try_exact/2]).
exact(M, V)  -> M#{k := V}.
assoc(M, V)  -> M#{k => V}.
try_exact(M, V) ->
    try M#{k := V} of R -> {ok, R}
    catch C:E -> {C, E} end.
'

echo "    on a map that HAS the key #{k => 0}:"
erl -noshell -pa "$WORK" -eval '
  io:format("      M#{k := 9}  -> ~p~n", [p_update:exact(#{k => 0}, 9)]),
  io:format("      M#{k => 9}  -> ~p~n", [p_update:assoc(#{k => 0}, 9)]),
  halt(0).' 2>&1

echo "    on a map that LACKS the key #{}:"
erl -noshell -pa "$WORK" -eval '
  io:format("      M#{k := 9}  -> ~p~n", [p_update:try_exact(#{}, 9)]),
  io:format("      M#{k => 9}  -> ~p~n", [p_update:assoc(#{}, 9)]),
  halt(0).' 2>&1
echo

echo "==============================================================="
echo "4. Erlang: can a PATTERN require a key to be ABSENT?"
echo "==============================================================="
echo "    There is no syntax for it. The only spelling is clause ORDER:"

erl_probe p_absent '
-module(p_absent).
-export([f/1]).
f(#{k := V}) -> {present, V};
f(#{})       -> absent.
'

erl -noshell -pa "$WORK" -eval '
  io:format("      f(#{k => 1}) -> ~p~n", [p_absent:f(#{k => 1})]),
  io:format("      f(#{})       -> ~p~n", [p_absent:f(#{})]),
  io:format("      f(#{j => 2}) -> ~p~n", [p_absent:f(#{j => 2})]),
  halt(0).' 2>&1
echo

echo "    ...and note the second clause #{} matches EVERY map, so a map"
echo "    pattern never closes a residual. Compare a catch-all-free version:"

erl_probe p_no_catchall '
-module(p_no_catchall).
-export([f/1]).
f(#{k := V}) -> {present, V}.
'

echo "==============================================================="
echo "5. Elixir PATTERN position: which operator exists?"
echo "==============================================================="

ex_probe "%{k => v} in a pattern (open match)" '
  m = %{a: 1, b: 2}
  %{a: x} = m
  IO.puts("      %{a: x} = %{a: 1, b: 2} bound x = #{x}")
  case m do
    %{} -> IO.puts("      %{} matches ANY map — the pattern is open")
  end
'

ex_probe "%{k := v} in a pattern" '
  case Code.string_to_quoted("case m do %{a := x} -> x end") do
    {:ok, ast}  -> IO.puts("      PARSED: #{inspect(ast)}")
    {:error, e} -> IO.puts("      REFUSED: #{inspect(e)}")
  end
'

ex_probe "does Elixir have := as an operator at all?" '
  case Code.string_to_quoted("a := b") do
    {:ok, ast}  -> IO.puts("      PARSED: #{inspect(ast)}")
    {:error, e} -> IO.puts("      REFUSED: #{inspect(e)}")
  end
'

ex_probe "can an Elixir pattern require a key ABSENT?" '
  m = %{a: 1}
  r = case m do
        %{b: _} -> :has_b
        %{}     -> :no_b_by_clause_order
      end
  IO.puts("      %{a: 1} against [%{b: _}, %{}] -> #{inspect(r)}")
'

echo "==============================================================="
echo "6. Elixir: is exhaustiveness over a map even checked?"
echo "==============================================================="

ex_probe "a case over a map with no catch-all" '
  code = "fn m -> case m do %{a: 1} -> :one end end"
  {result, _} = Code.eval_string(code)
  IO.puts("      compiled a case with no catch-all: #{inspect(is_function(result))}")
  try do
    result.(%{a: 2})
  rescue
    e in CaseClauseError -> IO.puts("      and it raises at RUNTIME: #{inspect(e.__struct__)}")
  end
'

echo "done."
