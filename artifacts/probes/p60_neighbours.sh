#!/usr/bin/env bash
# Ticket 60: what do Gleam and Elixir do about "who may name this module"? Both are run, not recalled.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
echo "== Gleam $(gleam --version | cut -d' ' -f2): gleam.toml internal_modules; checked ACROSS packages only"
mkdir -p $d/lib/src/lib/internal $d/app/src
printf 'name = "lib"\nversion = "1.0.0"\ntarget = "erlang"\ninternal_modules = ["lib/internal", "lib/internal/*"]\n' > $d/lib/gleam.toml
printf 'pub fn secret() -> Int { 42 }\n' > $d/lib/src/lib/internal/helper.gleam
printf 'import lib/internal/helper\npub fn api() -> Int { helper.secret() }\n' > $d/lib/src/lib.gleam
printf 'name = "app"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\nlib = { path = "../lib" }\n' > $d/app/gleam.toml
printf 'import lib/internal/helper\npub fn main() -> Int { helper.secret() }\n' > $d/app/src/app.gleam
echo "-- inside its own package (lib builds, lib.api calls lib/internal/helper):"
( cd $d/lib && gleam build 2>&1 | tail -2; echo "exit ${PIPESTATUS[0]}" )
echo "-- from another package:"
( cd $d/app && gleam build 2>&1 | grep -v "^ *$" | head -12; echo "exit ${PIPESTATUS[0]} (warnings, if any, are in the lines above)" )
echo "-- and the compiled app really calls it:"
( cd $d/app && erl -noshell -pa build/dev/erlang/app/ebin -pa build/dev/erlang/lib/ebin -eval 'io:format("app:main() -> ~p~n",[app:main()]), halt().' )
echo "-- a sibling module in the SAME package under a different directory:"
printf 'import lib/internal/helper\npub fn other() -> Int { helper.secret() }\n' > $d/lib/src/lib/sibling.gleam
( cd $d/lib && gleam build 2>&1 | tail -2; echo "exit ${PIPESTATUS[0]}" )
echo "== Elixir $(elixir -e 'IO.write(System.version())' 2>/dev/null): @moduledoc false hides docs; it does not stop a caller"
mkdir -p $d/ex && cat > $d/ex/x.exs <<'X'
defmodule Hidden do
  @moduledoc false
  @doc false
  def helper, do: 42
end
defmodule Outside do
  def go, do: Hidden.helper()
end
IO.inspect(Outside.go(), label: "caller outside, no warning, result")
X
( cd $d/ex && elixir x.exs 2>&1 | grep -v "latin1\|^$" | head -6 )
