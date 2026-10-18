#!/bin/bash
# Ticket 60 (ENG-242): which modules may name this one?
. "$(dirname "$0")/../env.sh"
work 60
mkdir -p Shop/Internal/Tax Shop/Billing Other/App Other/App2
cat > Shop/Internal/Tax/Tax.bs <<'B'
module Shop.Internal.Tax
public int Vat(int net)
Vat(n) -> n / 5
B
cat > Shop/Billing/Billing.bs <<'B'
module Shop.Billing
using Shop.Internal.Tax
public int Gross(int net)
Gross(n) -> n + Vat(n)
B
cat > Other/App/App.bs <<'B'
module Other.App
using Shop.Internal.Tax
public int Cheat(int net)
Cheat(n) -> Vat(n)
B
cat > Other/App2/App2.bs <<'B'
module Other.App2
public int Cheat2(int net)
Cheat2(n) -> Shop.Internal.Tax.Vat(n)
B
for v in c c60; do
  export BSC_EBIN=$S/$v/ebin
  echo "=============== bsc variant $v  ($( [ $v = c ] && echo baseline || echo 'prototype: Internal segment => nameable only from its parent namespace'))"
  for m in Shop/Billing Other/App Other/App2; do printf '%-14s ' $m; bsc --src-root . $m 2>&1 | head -1 | cut -c1-110; echo; done
done
echo "### baseline: does a qualified call skip 'using'? (App2 above) -> the 'never imported' error shows 'using' is already the single gate"

echo; echo "### Gleam: @internal attribute, and internal_modules in gleam.toml across a path dependency"
mkdir -p gl/lib/src/lib/internal gl/app/src && cd gl
printf 'name = "lib"\nversion = "1.0.0"\ninternal_modules = ["lib/internal", "lib/internal/*"]\n' > lib/gleam.toml
cat > lib/src/lib.gleam <<'B'
import lib/internal/secret
pub fn open() -> Int { secret.key() }
@internal
pub fn flagged() -> Int { 1 }
B
echo 'pub fn key() -> Int { 42 }' > lib/src/lib/internal/secret.gleam
printf 'name = "app"\nversion = "1.0.0"\n[dependencies]\nlib = { path = "../lib" }\n' > app/gleam.toml
echo "--- app (another package) imports lib/internal/secret:"
cat > app/src/app.gleam <<'B'
import lib/internal/secret
pub fn main() { secret.key() }
B
(cd app && gleam build --target erlang 2>&1 | head -12)
echo "--- app calls lib's @internal pub fn flagged():"
cat > app/src/app.gleam <<'B'
import lib
pub fn main() { lib.flagged() }
B
(cd app && gleam build --target erlang 2>&1 | head -8)
echo "--- lib itself (same package) imports its own internal module: builds?"
(cd lib && gleam build --target erlang 2>&1 | tail -2)
cd ..
echo; echo "### Elixir: @moduledoc false / @doc false — does either stop a caller?"
cat > m.ex <<'B'
defmodule Shop.Internal.Tax do
  @moduledoc false
  @doc false
  def vat(n), do: div(n, 5)
end
defmodule Other.App do
  def cheat(n), do: Shop.Internal.Tax.vat(n)
end
B
elixirc --no-docs -o . m.ex 2>&1 | grep -v warning
elixir -e 'IO.inspect(Other.App.cheat(50), label: "Other.App.cheat(50)")' 2>&1 | grep -v warning
