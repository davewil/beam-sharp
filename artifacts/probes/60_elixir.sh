#!/usr/bin/env bash
# CLAIM: Elixir has NO who-may-call check. `@moduledoc false` / `@doc false` only hide a module/function from DOC tools;
#   a caller in any module compiles with no warning; only `defp` (the "what" half) and a missing function are refused/warned.
# REFUTED IF: elixirc prints a warning or error for the call to the hidden-doc module/function (cases 1-2), or
#   Code.fetch_docs reports them visible. CONTROLS: calling a defp from another module, and calling a non-existent function, MUST be diagnosed.
. "$(dirname "$0")/env.sh"; export LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"; S=$(mktemp -d /tmp/probe60ex.XXXXXX); cd $S; mkdir out
cat > lib.ex <<'T'
defmodule Shop.Orders.Internal do
  @moduledoc false
  def recompute_total(lines), do: Enum.sum(lines)
end
defmodule Shop.Orders do
  @moduledoc "public"
  @doc false
  def helper(x), do: x + 1
  def total(lines), do: Shop.Orders.Internal.recompute_total(lines)
  defp secret(x), do: x
  def use_secret(x), do: secret(x)
end
T
cat > outsider.ex <<'T'
defmodule Audit do
  def a(l), do: Shop.Orders.Internal.recompute_total(l)   # @moduledoc false module
  def b(x), do: Shop.Orders.helper(x)                       # @doc false function
end
T
cat > ctl_private.ex <<'T'
defmodule Audit2 do
  def c(x), do: Shop.Orders.secret(x)                       # defp
  def d(x), do: Shop.Orders.nonexistent(x)                  # missing
end
T
echo "=== 1-2 outsider calls hidden-doc module and function (expect: no output, exit 0)"
elixirc -o out lib.ex outsider.ex; echo "exit $?"
echo "=== CONTROL: defp and missing function from outside (expect diagnostics)"
elixirc -pa out -o out ctl_private.ex 2>&1 | head -12; echo "exit ${PIPESTATUS[0]}"
echo "=== docs state"
elixir -pa out -e '
{:docs_v1, _, _, _, m, _, d} = Code.fetch_docs(Shop.Orders.Internal)
IO.inspect(m, label: "Internal moduledoc")
IO.inspect(Enum.map(d, fn {{k, n, a}, _, _, doc, _} -> {k, n, a, doc} end), label: "Internal fn docs")
{:docs_v1, _, _, _, _, _, d2} = Code.fetch_docs(Shop.Orders)
IO.inspect(Enum.map(d2, fn {{k, n, a}, _, _, doc, _} -> {k, n, a, doc} end), label: "Orders fn docs")
IO.inspect(Audit.a([1, 2, 3]), label: "runtime call outsider -> hidden module")'
