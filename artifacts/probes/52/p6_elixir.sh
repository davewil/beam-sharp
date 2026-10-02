#!/usr/bin/env bash
# P6: Elixir 1.14.0 -- (a) a call to a module that is not there; (b) mix's own
# check that a used module's APPLICATION is listed in mix.exs. Source for these
# checks is not installed here (only ebin), so this is probe-only, no file:line.
set -u
W="$(mktemp -d)"; cd "$W" || exit 2; fail=0
export MIX_HOME="$W/.mix" HEX_HOME="$W/.hex" MIX_ENV=dev
cat > a.ex <<'EOT'
defmodule A do
  def go, do: Req.new([])
end
EOT
echo "== (a) elixirc: call to absent module Req =="
elixirc a.ex 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}"
mkp() { # dir, extra_applications
  mkdir -p "$1/lib"; cat > "$1/mix.exs" <<EOT
defmodule P.MixProject do
  use Mix.Project
  def project, do: [app: :p, version: "0.1.0", deps: [], elixir: "~> 1.14"]
  def application, do: [extra_applications: $2]
end
EOT
  cat > "$1/lib/p.ex" <<'EOT'
defmodule P do
  require Logger
  def go, do: Logger.info("x")
end
EOT
}
mkp without "[]"; mkp with "[:logger]"
echo "== (b) mix project uses Logger (app :logger); mix.exs does NOT list it =="
( cd without && mix compile 2>&1 | grep -o '^warning: .* defined in application :[a-z_]*.*does not depend on :[a-z_]*' | sed 's/ defined in application.*does not depend on/ ... does not depend on/' ) | tee "$W/b.txt"
[ -s "$W/b.txt" ] || { echo "UNEXPECTED: no warning"; fail=1; }
echo "== (c) same code, extra_applications: [:logger] (separate project dir) =="
( cd with && mix compile 2>&1 | grep -c 'does not depend' ) | tee "$W/c.txt"
[ "$(cat "$W/c.txt")" = "0" ] || { echo "UNEXPECTED: still warns"; fail=1; }
rm -rf "${W:?}"; exit $fail
