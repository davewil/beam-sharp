#!/usr/bin/env bash
# Ticket 52: what does each neighbouring language do at COMPILE time when source uses a module of an
# application that is not on the code path? (B#'s answer today per the ticket: nothing; run-time error:undef.)
export PATH=/tmp/tools:$PATH
W=$(mktemp -d); cd "$W"
echo "=== Erlang (erlc): remote call to an absent module"
cat > e.erl <<'EOF'
-module(e).
-export([f/0]).
f() -> 'Elixir.Req':new([]).
EOF
erlc +debug_info e.erl; echo "erlc exit=$? (0 = compiled silently)"
erl -noshell -pa . -eval 'try e:f() catch C:R -> io:format("run time: ~p:~p~n",[C,R]) end, halt().'
echo "--- Erlang xref sees it (a separate tool, not the compiler):"
erl -noshell -pa . -eval 'xref:start(s), xref:set_default(s,[{warnings,false}]), xref:add_directory(s,"."), {ok,U}=xref:analyze(s,undefined_function_calls), io:format("xref undefined: ~p~n",[U]), halt().'
echo
echo "=== Elixir (elixirc): remote call to an absent module"
cat > x.ex <<'EOF'
defmodule X do
  def f, do: Req.new([])
end
EOF
elixirc x.ex 2>&1 | head -6; echo "elixirc exit=${PIPESTATUS[0]}"
echo "--- with @compile {:no_warn_undefined, Req}:"
cat > y.ex <<'EOF'
defmodule Y do
  @compile {:no_warn_undefined, Req}
  def f, do: Req.new([])
end
EOF
elixirc y.ex 2>&1 | head -3; echo "elixirc exit=${PIPESTATUS[0]}"
echo
echo "=== Gleam: import of an absent Gleam module vs @external to an absent Erlang module"
mkdir -p g/src && cd g
printf 'name = "g"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml
cat > src/g.gleam <<'EOF'
import req/client
pub fn main() { client.new() }
EOF
gleam build 2>&1 | grep -v -E '^\s*$' | head -8
cat > src/g.gleam <<'EOF'
@external(erlang, "Elixir.Req", "new")
fn new(opts: List(Int)) -> Int
pub fn main() { new([]) }
EOF
echo "--- @external to absent module:"; gleam build 2>&1 | tail -2; echo "gleam exit=${PIPESTATUS[0]}"
cd ..
echo
echo "=== Elm: import of an absent module (NOTE: needs elm/core from package.elm-lang.org; unreachable from this sandbox, so this section does NOT measure Elm's behaviour)"
mkdir -p el/src && cd el
cat > elm.json <<'EOF'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
EOF
printf 'module Main exposing (main)\nimport Req.Client as C\nmain = C.new\n' > src/Main.elm
HOME=$W elm make src/Main.elm --output=/dev/null 2>&1 | head -8
