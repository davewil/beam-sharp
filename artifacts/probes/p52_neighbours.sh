#!/usr/bin/env bash
# Ticket 52: how do Erlang, Elixir and Gleam bind source to the application it needs?
# Four questions, each answered by running the tool: (1) does a foreign call to an undeclared app
# stop the build, (2) what text does the tool print, (3) where does the declaration live,
# (4) does it carry a version.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
echo "== Erlang 28: erlc accepts a remote call into any module; xref is the separate tool that notices"
printf -- '-module(e52).\n-export([f/0]).\nf() -> mydep:answer().\n' > $d/e52.erl
erlc +debug_info -o $d $d/e52.erl && echo "erlc exit: $? (silent)"
erl -noshell -eval '
  {ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
  {ok,_}=xref:add_directory(s,"'$d'"),
  {ok,U}=xref:analyze(s,undefined_function_calls), io:format("xref undefined_function_calls: ~p~n",[U]), halt().' 2>&1 | head -3
echo "== Elixir $(elixir -e 'IO.write(System.version())' 2>/dev/null): mix warns when a used app is not listed in mix.exs"
mkdir -p $d/mx/lib && cat > $d/mx/mix.exs <<'X'
defmodule Mx.MixProject do
  use Mix.Project
  def project, do: [app: :mx, version: "0.1.0", elixir: "~> 1.14", deps: []]
  def application, do: [extra_applications: [:logger]]
end
X
cat > $d/mx/lib/mx.ex <<'X'
defmodule Mx do
  def f, do: :xmerl_scan.string(~c"<a/>")
  def g, do: :mydep.answer()
end
X
( cd $d/mx && MIX_HOME=$d/mixhome mix compile 2>&1 | grep -v "^Compiling\|^Generated\|latin1\|^$" | head -14; echo "mix exit: ${PIPESTATUS[0]}" )
echo "== Gleam $(gleam --version | cut -d' ' -f2): @external names any Erlang module with no check; an import needs a dependency"
mkdir -p $d/gl/src && printf 'name = "g52app"\nversion = "1.0.0"\ntarget = "erlang"\n' > $d/gl/gleam.toml
cat > $d/gl/src/g52app.gleam <<'X'
@external(erlang, "mydep", "answer")
pub fn answer() -> Int
X
( cd $d/gl && gleam build 2>&1 | tail -2; echo "gleam exit (external to undeclared app): ${PIPESTATUS[0]}" )
cat > $d/gl/src/g52app.gleam <<'X'
import gleam/list
pub fn f() { list.length([1]) }
X
( cd $d/gl && gleam build 2>&1 | grep -v "^ *$" | head -8; echo "gleam exit (import without dependency): ${PIPESTATUS[0]}" )
echo "== Elm 0.19.3: elm.json is the manifest and is validated before any source is read (package registry is unreachable here, so no further)"
mkdir -p $d/elm/src && cat > $d/elm/elm.json <<'X'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
X
printf 'module Main exposing (f)\nimport Json.Decode\nf = 1\n' > $d/elm/src/Main.elm
( cd $d/elm && elm make src/Main.elm --output=/dev/null 2>&1 | head -5 )
