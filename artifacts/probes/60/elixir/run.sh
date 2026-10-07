#!/bin/sh
# Elixir 1.18.5: @moduledoc false / @doc false, mix xref. Boundary is NOT installed and hex is unreachable.
export PATH=$HOME/.nix-profile/bin:$PATH ELIXIR_ERL_OPTIONS="+fnu" MIX_HOME=${TMPDIR:-/tmp}/mixhome HEX_OFFLINE=1
cd "$(dirname "$0")" || exit 1
mix compile --force 2>&1 | tail -3; echo "[compile exit $?]"
echo "== mix xref callers Shop.Orders.Cache"; mix xref callers Shop.Orders.Cache 2>&1
mix run -e '{:docs_v1, _, _, _, m, _, _} = Code.fetch_docs(Shop.Orders.Cache); IO.inspect(m, label: "moduledoc"); IO.inspect(Other.Thing.go(4), label: "Other.Thing.go(4)")' 2>&1 | tail -2
rm -rf _build
