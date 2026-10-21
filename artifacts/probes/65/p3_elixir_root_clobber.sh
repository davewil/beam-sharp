#!/bin/sh
# 65 / probe 3 — `module Elixir.Enum` compiles under bsc and emits Elixir.Enum.beam. What happens if an
# Elixir VM loads it? (Run in a throwaway VM; this deliberately breaks `Enum` inside it.)
set -u
BSC=${BSC:?set BSC}; W=${PROBE_TMP:-$(mktemp -d)}
mkdir -p "$W/Elixir/Enum"
printf 'module Elixir.Enum\n\npublic int Go(int x)\nGo(x) -> x\n' > "$W/Elixir/Enum/m.bs"
"$BSC" --src-root "$W" -o "$W/out" "$W/Elixir/Enum" || exit 2
cat > "$W/clobber.exs" <<X
IO.inspect(Enum.map([1, 2], &(&1 + 1)), label: "Enum.map before")
Code.prepend_path("$W/out")
:code.purge(Enum); :code.delete(Enum)
IO.inspect(Code.ensure_loaded(Enum), label: "load B# Elixir.Enum")
IO.inspect(function_exported?(Enum, :map, 2), label: "Enum.map/2 still exported?")
IO.inspect(Enum.map([1, 2], &(&1 + 1)), label: "Enum.map after")
X
cd "$W" && elixir clobber.exs 2>&1 | cut -c1-200 | head -8; rm -f "$W"/erl_crash.dump
