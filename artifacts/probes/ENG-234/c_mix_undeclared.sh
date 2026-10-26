#!/usr/bin/env bash
# (c) Elixir/mix: calling a module from a package the project does not declare.
# A local path dep ("depa") stands in for Req; no network used.
set -u; D=$(mktemp -d); cd "$D"
mkdir -p depa/lib app/lib
cat > depa/mix.exs <<'X'
defmodule Depa.MixProject do
  use Mix.Project
  def project, do: [app: :depa, version: "0.1.0", elixir: "~> 1.14", deps: []]
  def application, do: []
end
X
echo 'defmodule Depa do def hello, do: :hi end' > depa/lib/depa.ex
(cd depa && mix compile >/dev/null 2>&1 && echo "depa built: $(ls _build/dev/lib/depa/ebin)")
echo "### case 1: app does not declare depa, depa NOT on the code path"
cat > app/mix.exs <<'X'
defmodule App.MixProject do
  use Mix.Project
  def project, do: [app: :app, version: "0.1.0", elixir: "~> 1.14", deps: []]
  def application, do: []
end
X
echo 'defmodule App do def go, do: Depa.hello() end' > app/lib/app.ex
(cd app && mix compile 2>&1 | head -12; echo "mix exit=${PIPESTATUS[0]}")
echo "### case 2: depa on the code path via ERL_LIBS-style -pa but still undeclared"
(cd app && rm -rf _build && ERL_LIBS=$D/depa/_build/dev/lib mix compile 2>&1 | head -12; echo "mix exit=${PIPESTATUS[0]}")
echo "### case 3: declared as a path dep"
sed -i 's|deps: \[\]\]|deps: [{:depa, path: "../depa"}]]|' app/mix.exs
(cd app && rm -rf _build && mix compile 2>&1 | head -12; echo "mix exit=${PIPESTATUS[0]}")
