#!/usr/bin/env bash
# Probe: how does Mix record and check a dependency at compile time, in a real
# scratch project? Uses a PATH dependency rather than a hex one because
# repo.hex.pm is unreachable from this sandbox (see 52f for the captured proxy
# denial) -- a path dependency exercises exactly the same "declared but not
# present" check Mix runs before compiling hex deps, with no network at all.
set -euo pipefail
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

mix new libdep >/dev/null
cat > libdep/lib/libdep.ex <<'EOF'
defmodule Libdep do
  def greet(name), do: "hello, #{name}"
end
EOF

mix new app >/dev/null
cd app
python3 - <<'PY'
s = open("mix.exs").read()
s = s.replace("defp deps do\n    [\n",
              "defp deps do\n    [\n      {:libdep, path: \"../libdep\"},\n")
open("mix.exs", "w").write(s)
PY
cat > lib/app.ex <<'EOF'
defmodule App do
  def run(name), do: Libdep.greet(name)
end
EOF

echo "=== real generated deps() in mix.exs (real mix.exs, path dep added) ==="
grep -A4 "defp deps" mix.exs

echo
echo "=== 1. dependency DECLARED and PRESENT: mix compile ==="
mix deps.get >/dev/null 2>&1 || true
mix compile
echo "exit: $?"
mix run -e 'IO.puts(App.run("world"))'

echo
echo "=== 2. dependency DECLARED, directory made ABSENT: mix compile ==="
mv ../libdep ../libdep_hidden
rm -rf _build deps
set +e
mix compile
echo "exit: $?"
set -e
mv ../libdep_hidden ../libdep

echo
echo "=== 3. dependency UNDECLARED (removed from mix.exs) but still CALLED in source ==="
python3 - <<'PY'
s = open("mix.exs").read()
s = s.replace('      {:libdep, path: "../libdep"},\n', '')
open("mix.exs", "w").write(s)
PY
grep -A4 "defp deps" mix.exs
rm -rf _build deps
echo "--- mix compile (undeclared dep, module unreachable) ---"
mix compile
echo "exit: $?"
echo "--- mix run: actually calling it ---"
set +e
mix run -e 'IO.puts(App.run("world"))'
echo "exit: $?"
set -e
