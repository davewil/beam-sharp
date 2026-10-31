#!/usr/bin/env bash
# Probe (i): does Elixir `defmodule Map` warn / clobber / crash the type checker?  Elixir 1.14 / OTP 24-built on this machine.
# Run: bash p1_elixir_defmodule_map.sh   (writes nothing outside a mktemp dir)
set -u
T=$(mktemp -d); cd "$T"
elixir --version 2>&1 | tail -1
echo "--- A: redefine Map in a script, then call Map.get and Map.update!/3 (the call the ticket says the checker made)"
cat > a.exs <<'X'
defmodule Map do
  def get(_m, _k), do: :mine_not_stdlibs
end
IO.inspect(Map.get(%{a: 1}, :a), label: "Map.get after clobber")
IO.inspect(function_exported?(Map, :update!, 3), label: "Map.update!/3 still exported")
IO.inspect(:code.which(Map), label: "code.which(Map)")
IO.inspect(Map.module_info(:exports) |> length, label: "exports of Map now")
# now use ordinary Elixir that goes through Map internally
try do
  IO.inspect(Enum.into([a: 1], %{}), label: "Enum.into")
  IO.inspect(Map.new([a: 1]), label: "Map.new")
rescue e -> IO.puts("RESCUED: " <> Exception.message(e))
end
X
elixir a.exs 2>&1 | head -40
echo "exit=$?"
echo "--- B: same, but compiled with elixirc (the path the type checker runs on) and a struct using Map functions"
cat > b.ex <<'X'
defmodule Map do
  def get(_m, _k), do: :mine
end
defmodule User do
  defstruct [:a]
  def f(m), do: Map.update!(m, :a, & &1)   # remote call into the clobbered module
end
X
elixirc b.ex 2>&1 | head -40
echo "elixirc exit=${PIPESTATUS[0]}"
echo "--- C: does the stdlib's own Map.update!/3 exist at all in this Elixir? (control, no clobber)"
elixir -e 'IO.inspect(function_exported?(Map, :update!, 3))'
rm -rf "$T"
