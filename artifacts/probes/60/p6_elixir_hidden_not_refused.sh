#!/usr/bin/env bash
# Probe 6 - Elixir: @moduledoc false hides a module from docs. Does anything refuse a caller? What can xref say?
set -eu
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; cd $d
mkdir -p lib; cat > mix.exs <<'EOF'
defmodule P.MixProject do
  use Mix.Project
  def project, do: [app: :p, version: "0.1.0", elixir: "~> 1.14"]
end
EOF
cat > lib/ledger.ex <<'EOF'
defmodule Shop.Billing.Ledger do
  @moduledoc false
  def recompute(net, tax), do: net + tax
end
EOF
cat > lib/billing.ex <<'EOF'
defmodule Shop.Billing do
  def charge(n, t), do: Shop.Billing.Ledger.recompute(n, t)
end
EOF
cat > lib/reports.ex <<'EOF'
defmodule Shop.Reports do
  def restate(n), do: Shop.Billing.Ledger.recompute(n, 0)
end
EOF
MIX_ENV=dev mix compile 2>&1 | grep -v "^Compiling\|^Generated" || true
echo "6a Reports calling the @moduledoc-false module: compiled, no error/warning above"
echo "6b docs chunk of the hidden module:"; mix run -e '{:docs_v1, _, _, _, md, _, _} = Code.fetch_docs(Shop.Billing.Ledger); IO.inspect(md, label: "moduledoc"); IO.inspect(Shop.Reports.restate(5), label: "Reports.restate(5)")' 2>&1 | tail -2
echo "6c mix xref graph --sink: the tooling answers 'who names Ledger' but refuses nobody:"
mix xref graph --sink lib/ledger.ex --format plain 2>&1 | tail -4
