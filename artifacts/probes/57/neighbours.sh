#!/bin/bash
# Ticket 57: how do Erlang, Elixir, Gleam, Elm treat a negative integer literal at a pattern / guard site?
. "$(dirname "$0")/../env.sh"
work 57n
echo "### Elixir: AST of -5 (is it folded into the literal at parse time?)"
elixir -e 'IO.inspect(Code.string_to_quoted!("-5")); IO.inspect(Code.string_to_quoted!("x >= -5")); IO.inspect(Code.string_to_quoted!("- 5")); IO.inspect(Code.string_to_quoted!("-(5)"))' 2>&1 | grep -v warning
echo "### Elixir: -5 as a pattern and in a guard compiles and matches"
elixir -e 'defmodule M do
 def f(-5), do: :a
 def f(x) when x >= -5, do: :b
 def f(_), do: :c
end
IO.inspect({M.f(-5), M.f(-1), M.f(-9)})' 2>&1 | grep -v warning
echo "### Elixir: what the Erlang compiler receives for the guard (abstract code of the compiled module)"
cat > m2.ex <<'B'
defmodule M2 do
  def f(x) when x >= -5, do: :b
  def f(_), do: :c
end
B
elixirc --no-docs -o . m2.ex 2>&1 | grep -v warning
elixir -e '{:ok,{_,[abstract_code: {_,fs}]}} = :beam_lib.chunks(~c"Elixir.M2.beam", [:abstract_code])
for {:function,_,:f,1,cl} <- fs, do: IO.inspect(cl, limit: :infinity)' 2>&1 | grep -v warning | head -14
echo "### Gleam: negative literal as pattern, in guard, and the Erlang it emits"
mkdir -p g/src && cd g && printf 'name = "g"\nversion = "1.0.0"\n' > gleam.toml
cat > src/g.gleam <<'B'
pub fn f(x: Int) -> Int {
  case x {
    -5 -> 1
    n if n >= -5 -> 2
    _ -> 3
  }
}
pub fn sub() -> Int { 0 - 5 }
B
gleam build --target erlang 2>&1 | tail -3
erl -noshell -eval '{beam_file,_,_,_,_,Is}=beam_disasm:file("build/dev/erlang/g/ebin/g.beam"), [io:format("~p~n",[C]) || {function,f,1,_,C} <- Is], halt().' 2>&1 | grep -o '{test,[a-z_]*,{f,[0-9]*},\[{x,0},{integer,-\?[0-9]*}\]}' | head
echo "### Gleam: is there a refinement/where-type? (try one)"
cat > src/g.gleam <<'B'
pub type T = Int where value >= 0
B
gleam build --target erlang 2>&1 | head -6
cd ..
echo "### Elm: needs elm/core from package.elm-lang.org, which this sandbox cannot reach"
curl -sS -m 15 -o /dev/null -w "package.elm-lang.org -> HTTP %{http_code}\n" https://package.elm-lang.org/all-packages 2>&1 | tail -1
echo "### Elm: negative pattern literal (expected to fail on dependency fetch, not on the language)"
mkdir -p e/src && cd e && cat > elm.json <<'B'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
B
cat > src/Main.elm <<'B'
module Main exposing (f)
f : Int -> Int
f x = case x of
        -5 -> 1
        _ -> 2
B
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -8
