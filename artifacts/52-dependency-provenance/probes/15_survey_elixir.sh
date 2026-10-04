#!/bin/sh
# How Elixir declares provenance. `mix new`, a path dep in mix.exs, the generated .app, what the
# compiler says about a call to a module that is not there, and Application.ensure_all_started.
# Runs on the system OTP 25 + Elixir 1.14.0; Elixir's own .ex sources are NOT installed here (only
# beams), so nothing below cites Elixir source -- only files mix generated and output it printed.
export PATH=/usr/bin:/bin
. "$(dirname "$0")/env.sh"; export PATH=/usr/bin:/bin   # env.sh prepends otp28; undo for this probe
W=${W:-/tmp/p52}
rm -rf $W/ex && mkdir -p $W/ex && cd $W/ex
mix new probeapp >/dev/null 2>&1
cd probeapp
cp -r $FIX/greeter ../greeter_dep && rm -rf ../greeter_dep/_build
cat > mix.exs <<'M'
defmodule Probeapp.MixProject do
  use Mix.Project
  def project, do: [app: :probeapp, version: "0.1.0", deps: deps()]
  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:greeter, path: "../greeter_dep"}]
end
M
cat > lib/probeapp.ex <<'E'
defmodule Probeapp do
  def hi(n), do: Greeter.hello(n)
  # a call into a module that no dependency provides
  def bad, do: Nonesuch.Thing.run(1)
end
E
echo "== mix.exs (lines)"; cat -n mix.exs
echo "== mix compile: is the call to a module NOT in any dependency caught at compile time?"
mix compile 2>&1 | head -20
echo "== exit status of that compile"; mix compile --force >/dev/null 2>&1; echo "exit=$?"
echo "== the .app mix generated for probeapp: 'applications' is INFERRED from mix.exs deps + extra_applications"
cat -n _build/dev/lib/probeapp/ebin/probeapp.app
echo "== mix.lock-equivalent for a path dep: none is written; deps.get for a path dep"
ls; ls -a | grep -i lock || echo "(no mix.lock for a path-only dep)"
echo "== run time: Application.ensure_all_started starts the dependency's tree, or says which app is missing"
mix run -e 'IO.inspect(Application.ensure_all_started(:probeapp))' 2>&1 | head -3
mix run -e 'IO.inspect(Application.ensure_all_started(:req))' 2>&1 | head -3
echo "== removing the dep from mix.exs but leaving the call: the module is simply 'undefined' (warning), not 'dependency missing'"
sed -i 's/defp deps, do: .*/defp deps, do: []/' mix.exs
mix compile --force 2>&1 | grep -i -B1 -A4 "undefined\|Greeter" | head -12
