#!/usr/bin/env bash
# Probe 65/01: what does `defmodule Map` do on the installed Elixir?
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
elixir --version | tail -1
echo "=== A. script mode (elixir shadow.exs), stderr merged"
elixir shadow.exs 2>&1
echo "exit=$?"
echo
echo "=== B. compiled mode: elixirc a module Map, then call stdlib Map from a second file"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/map.ex" <<'EOS'
defmodule Map do
  def get(_m, _k), do: :mine_not_stdlibs
end
EOS
cat > "$T/use.exs" <<'EOS'
IO.inspect(Map.get(%{a: 1}, :a), label: "Map.get")
IO.inspect(try do Map.put(%{}, :a, 1) rescue e -> {:raised, e.__struct__} end, label: "Map.put")
EOS
(cd "$T" && elixirc map.ex 2>&1; echo "elixirc exit=$?"; elixir -pa . use.exs 2>&1; echo "use exit=$?")
