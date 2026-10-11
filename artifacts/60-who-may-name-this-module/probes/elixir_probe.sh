#!/usr/bin/env bash
# Probe (c): Elixir 1.20.x -- is "who may call me" enforced by defp / @moduledoc false / @doc false /
# @deprecated / xref / no_warn_undefined? And what hook does the compiler offer instead?
# One command: ./elixir_probe.sh
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
export ELIXIR_ERL_OPTIONS="+fnu"
HERE=$(cd "$(dirname "$0")" && pwd); W=$(mktemp -d); cp -r "$HERE/elixir/." "$W/"; cd "$W"
elixir --version 2>&1 | tail -1
echo "### 1. Elsewhere calls Shop.Orders.recompute_total (@doc false in a @moduledoc false module) and old_total (@deprecated)"
mix compile 2>&1; echo "exit=$?"
echo
echo "### 2. mix xref: the call graph is queryable, but it is a report, not a gate"
mix xref callers Shop.Orders 2>&1; echo "exit=$?"
echo
echo "### 3. NEGATIVE CONTROL: defp across modules (a warning, not an error, until escalated)"
cat > lib/elsewhere_priv.ex <<'EOT'
defmodule ElsewherePriv do
  def poke(n), do: Shop.Orders.hidden(n)
end
EOT
mix compile 2>&1 | grep -v '^\s*$' | head -6; echo "exit=${PIPESTATUS[0]}  <- a WARNING, the build succeeds"
mix run -e 'ElsewherePriv.poke(1)' 2>&1 | grep -m1 UndefinedFunctionError
echo "--- escalated with --warnings-as-errors:"; rm -rf _build; mix compile --warnings-as-errors 2>&1 | grep -m2 -i 'error\|warnings-as'; echo "exit=${PIPESTATUS[0]}"
rm lib/elsewhere_priv.ex
echo
echo "### 4. @compile {:no_warn_undefined, ...} only silences the undefined-module warning; it is not a visibility switch"
cp lib/undef.ex.disabled lib/undef.ex
rm -rf _build; mix compile 2>&1 | grep -A3 -i 'warning' | head -8
sed -i '1a\  @compile {:no_warn_undefined, Not.Defined}' lib/undef.ex
rm -rf _build; echo "--- with @compile {:no_warn_undefined, Not.Defined}:"; mix compile 2>&1 | grep -c -i 'undefined' ; rm lib/undef.ex
echo
echo "### 5. a who-may-call-me rule via the compiler tracer hook (what the Boundary library is built on)"
rm -rf _build; WITH_TRACER=1 mix compile 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"
echo "--- remove the offending caller; the allowed friend (Shop.Reports) alone passes:"
rm lib/elsewhere.ex; rm -rf _build; WITH_TRACER=1 mix compile 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"
