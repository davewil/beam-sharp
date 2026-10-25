#!/usr/bin/env bash
# Ticket 60 survey. What does each neighbour's compiler do when a module names something its author marked "not for you"?
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d)
echo '--- Gleam: a dependency package marks a module internal; an app package imports it (path dependency, no Hex needed)'
mkdir -p $W/dep/src/dep/internal $W/app/src
cat > $W/dep/gleam.toml <<'X'
name = "dep"
version = "1.0.0"
target = "erlang"
internal_modules = ["dep/internal", "dep/internal/*"]
X
printf 'pub fn helper() -> Int { 41 }\n' > $W/dep/src/dep/internal/h.gleam
printf 'import dep/internal/h\npub fn api() -> Int { h.helper() + 1 }\n' > $W/dep/src/dep.gleam
cat > $W/app/gleam.toml <<'X'
name = "app"
version = "1.0.0"
target = "erlang"
[dependencies]
dep = { path = "../dep" }
X
printf 'import dep\nimport dep/internal/h\npub fn main() -> Int { dep.api() + h.helper() }\n' > $W/app/src/app.gleam
(cd $W/app && gleam build 2>&1 | head -14; echo "[gleam rc=${PIPESTATUS[0]}]")
echo '--- Gleam: the same import from INSIDE the declaring package (control: must compile)'
printf 'import dep\npub fn main() -> Int { dep.api() }\n' > $W/app/src/app.gleam
(cd $W/app && gleam build 2>&1 | tail -2; echo "[gleam rc=${PIPESTATUS[0]}]")
echo '--- Gleam: the @internal attribute on a pub fn, used from another package'
printf 'name = "dep"\nversion = "1.0.0"\ntarget = "erlang"\n' > $W/dep/gleam.toml
printf '@internal\npub fn helper() -> Int { 41 }\npub fn api() -> Int { helper() + 1 }\n' > $W/dep/src/dep.gleam
printf 'name = "app"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\ndep = { path = "../dep" }\n' > $W/app/gleam.toml
printf 'import dep\npub fn main() -> Int { dep.helper() }\n' > $W/app/src/app.gleam
(cd $W/app && gleam build 2>&1 | head -12; echo "[gleam rc=${PIPESTATUS[0]}]")
echo '--- Elixir: @doc false / @moduledoc false hides from docs; does calling it from another module warn or fail?'
mkdir -p $W/ex && cat > $W/ex/a.ex <<'X'
defmodule Shop.Pricing do
  @moduledoc false
  @doc false
  def recompute(n), do: n * 2
end
defmodule Other do
  def peek(n), do: Shop.Pricing.recompute(n)
end
IO.inspect(Other.peek(21))
X
(cd $W/ex && elixir a.ex 2>&1 | grep -v 'native name encoding')
echo '--- Elixir: defp is the only enforced visibility'
cat > $W/ex/b.ex <<'X'
defmodule P do
  defp hidden(n), do: n
end
defmodule Q do
  def peek(n), do: P.hidden(n)
end
X
(cd $W/ex && elixir b.ex 2>&1 | grep -v 'native name encoding' | head -4)
echo '--- Erlang: -export is the only visibility; a non-exported function is undef from outside, any exported one is callable by every module'
cat > $W/p.erl <<'X'
-module(p).
-export([pub/1]).
pub(N) -> hid(N).
hid(N) -> N * 2.
X
erlc -o $W $W/p.erl && erl -noshell -pa $W -eval 'io:format("~p ~p~n",[catch p:pub(21), element(1, (catch p:hid(21)))]), halt().'
