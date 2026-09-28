#!/bin/sh
# PREDICTION: `mix xref callers Shop.Orders` (Elixir 1.14) lists every caller module of a public function, i.e. Elixir,
# like OTP xref, can REPORT who calls whom after compile, and has no enforcement mode; `mix xref --help` lists no
# "restrict"/"allow" option. Runs offline (no deps).
S=${TMPDIR:-/tmp}/b60_mixproj; rm -rf "$S"; mkdir -p "$S/lib"; cd "$S" || exit 1
cat > mix.exs <<'X'
defmodule P.MixProject do
  use Mix.Project
  def project, do: [app: :p, version: "0.1.0", elixir: "~> 1.14", deps: []]
end
X
cat > lib/orders.ex <<'X'
defmodule Shop.Orders do
  @doc false
  def recompute_total(l), do: Enum.sum(l)
end
X
cat > lib/reports.ex <<'X'
defmodule Shop.Reports do
  def go, do: Shop.Orders.recompute_total([1])
end
defmodule Outsider do
  def go, do: Shop.Orders.recompute_total([2])
end
X
export MIX_ENV=dev HEX_OFFLINE=1
mix compile 2>&1 | tail -2
echo "--- mix xref callers Shop.Orders"
mix xref callers Shop.Orders 2>&1
echo "--- mix xref --help option names"
mix help xref 2>&1 | grep -E '^\s+(\*|--)|^  [a-z-]+ ' | head -30
echo "--- mix help xref: lines mentioning restrict/allow/visib"
mix help xref 2>&1 | grep -i -E 'restrict|allow|visib|friend|internal' | head
