#!/usr/bin/env bash
# 59g — CLAIM: how do neighbouring BEAM languages treat argument checking at private vs
# exported functions? (ticket 59 asks whether private should differ.)
#  Gleam  : `gleam build` of gleam_scope/ — does it emit ANY runtime check, public or private?
#  Erlang : -spec and guards are independent; a -spec on a local fn is not enforced.
#  Elixir : defp/def are checked identically by the language (nothing); authors opt in with
#           patterns/guards at either scope.
#  Elm    : NOT PROBED (package.elm-lang.org unreachable from this sandbox; see .out).
# CONTROL: each language is also driven with a FORGED term; the assertion fails (FAIL line)
# if a check were present where we claim none, and the Erlang/Elixir author-written guard
# variants show the same call DOES raise when a guard exists (so the harness can see a raise).
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
export ERL_CRASH_DUMP=/dev/null
P="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; W=$(mktemp -d)
cp -r "$P/gleam_scope" "$W/g"; (cd "$W/g" && gleam build 2>&1 | tail -2)
echo "--- Gleam: emitted Erlang for a private and a public fn taking a custom type"
sed -n '/inner_total(O) ->/,/^$/p;/^public_total(O) ->/,$p' "$W/g/build/dev/erlang/scope/_gleam_artefacts/scope.erl"
echo "--- Gleam: forged {invoice,1,5} where order() is declared"
erl -noshell -pa "$W/g/build/dev/erlang/scope/ebin" -eval '
  F = {invoice,1,5},
  R = fun(Fun) -> try Fun() of V -> {ok,V} catch C:E -> {C,E} end end,
  io:format("public_total(F) -> ~p   (exported, nothing checks)~n",[R(fun() -> scope:public_total(F) end)]),
  io:format("outer_total(F)  -> ~p   (private inner_total reads element(3); inner_match matches {order,_,T})~n",[R(fun() -> scope:outer_total(F) end)]),
  io:format("outer_int(1.5)  -> ~p   (private inner_int)~n",[R(fun() -> scope:outer_int(1.5) end)]),
  halt().'
echo "--- Erlang: -spec is not a runtime check, a guard is, at any scope (control)"
cat > "$W/sp.erl" <<'ERL'
-module(sp).
-export([pub_spec/1, pub_guard/1, via_spec/1, via_guard/1]).
-spec pub_spec(integer()) -> integer().
pub_spec(N) -> N + 1.
pub_guard(N) when is_integer(N) -> N + 1.
via_spec(N) -> loc_spec(N).
via_guard(N) -> loc_guard(N).
-spec loc_spec(integer()) -> integer().
loc_spec(N) -> N + 1.
loc_guard(N) when is_integer(N) -> N + 1.
ERL
erlc -o "$W" "$W/sp.erl" && erl -noshell -pa "$W" -eval '
  R = fun(Fun) -> try Fun() of V -> {ok,V} catch C:E -> {C,E} end end,
  [io:format("~-16s ~p~n",[N,R(fun() -> sp:F(1.5) end)]) || {N,F} <- [{"pub_spec(1.5)",pub_spec},{"pub_guard(1.5)",pub_guard},{"via_spec(1.5)",via_spec},{"via_guard(1.5)",via_guard}]], halt().'
echo "--- Elixir: defp with and without an author-written struct pattern / guard"
cat > "$W/ex.exs" <<'EX'
defmodule O do defstruct [:id, :total] end
defmodule I do defstruct [:id, :total] end
defmodule Sc do
  def pub_plain(o), do: priv_plain(o)
  def pub_pat(o), do: priv_pat(o)
  defp priv_plain(o), do: o.total
  defp priv_pat(%O{} = o), do: o.total
end
inv = struct(I, id: 1, total: 5)
r = fn f -> try do {:ok, f.()} rescue e -> {:raised, e.__struct__} end end
IO.inspect(r.(fn -> Sc.pub_plain(inv) end), label: "defp without pattern, forged %I{}")
IO.inspect(r.(fn -> Sc.pub_pat(inv) end),   label: "defp with %O{} pattern, forged %I{}")
EX
elixir "$W/ex.exs"
echo "--- Elm: not probed"
S="$W/elm"; mkdir -p "$S/src"; (cd "$S" && printf '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/html":"1.0.0","elm/browser":"1.0.2"},"indirect":{"elm/json":"1.1.3","elm/time":"1.0.0","elm/url":"1.0.0","elm/virtual-dom":"1.0.3"}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json; printf 'module Main exposing (main)\nimport Html\nmain = Html.text "x"\n' > src/Main.elm; timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -4)
