#!/bin/sh
# 62 / probe 1 — which call spellings can Elixir use against an Erlang module 'Shop' exporting 'New'/1?
# Each spelling is evaluated in its own `elixir -e` so a SyntaxError in one cannot mask another.
set -u
D=$(cd "$(dirname "$0")" && pwd); W=${PROBE_TMP:-$(mktemp -d)}
erlc -o "$W" "$D/Shop.erl" || exit 2
try() { printf '%-46s -> ' "$1"; elixir -pa "$W" -e "IO.inspect($1)" 2>&1 | head -1 | cut -c1-110; }
elixir --version | tail -1
try ':Shop.New(1)'
try ':"Shop".New(1)'
try ':"BSharp.Shop".New(1)'
try ':Shop."New"(1)'
try ':"Shop"."New"(1)'
try 'apply(:Shop, :New, [1])'
try ':erlang.apply(:Shop, :New, [1])'
try ':Shop.new(1)'
echo '--- defdelegate shim, one line per function, in the adopter'"'"'s own code'
cat > "$W/shim.exs" <<'X'
defmodule MyApp.ShopApi do
  defdelegate new(id), to: :Shop, as: :New
  defdelegate which(o), to: :Shop, as: :Which
end
IO.inspect(MyApp.ShopApi.new(7))
IO.inspect(MyApp.ShopApi.which(MyApp.ShopApi.new(7)))
X
elixir -pa "$W" "$W/shim.exs" 2>&1 | head -4
echo '--- does the Elixir formatter keep the quoted spelling, and does a plain compile warn?'
elixir -e 'IO.puts(Code.format_string!(~S[x = :Shop."New"(1)]))'
cat > "$W/q.exs" <<'X'
defmodule Q do
  def go, do: :Shop."New"(1)
end
IO.inspect(Q.go())
X
elixir -pa "$W" "$W/q.exs" 2>&1 | head -3
