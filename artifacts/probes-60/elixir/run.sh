#!/bin/sh
# Elixir: @moduledoc false is documentation-only; xref sees caller edges.
cd "$(dirname "$0")/proj" && rm -rf _build && mix compile 2>&1
mix run --no-start -e 'IO.inspect(Code.fetch_docs(Shop.Orders.Internal), label: "docs")
IO.inspect(Shop.Billing.charge(1), label: "runtime call to @moduledoc false module")
IO.inspect(Shop.Orders.Internal.module_info(:exports), label: "exports")
IO.inspect(try do Shop.Orders.Internal.hidden(1) rescue e -> e end, label: "runtime defp call")' 2>&1
mix xref callers Shop.Orders.Internal
