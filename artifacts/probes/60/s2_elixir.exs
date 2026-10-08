# S2: Elixir 1.14. @moduledoc false / @doc false hide from DOCS only; defp is the only compile-enforced hiding.
defmodule Acme.Orders.Internal.Pricing do
  @moduledoc false
  @doc false
  def compute(n), do: n * 2
  defp secret(n), do: n + 1
  def via(n), do: secret(n)
end

defmodule Acme.Billing do
  def due(n), do: Acme.Orders.Internal.Pricing.compute(n)   # compiles, no warning, no error
end
IO.puts("hidden module called from another module: #{Acme.Billing.due(5)}")
{:docs_v1, _, _, _, moddoc, _, fdocs} = Code.fetch_docs(Acme.Orders.Internal.Pricing)
IO.inspect(moddoc, label: "moduledoc (false => :hidden)")
IO.inspect(Enum.map(fdocs, fn {{k, n, a}, _, _, d, _} -> {k, n, a, d} end), label: "per-function docs")
IO.inspect(apply(Acme.Orders.Internal.Pricing, :compute, [5]), label: "dynamic apply")
IO.inspect(Acme.Orders.Internal.Pricing.module_info(:exports) |> Enum.reject(&match?({:module_info, _}, &1)), label: "exports")
# control: defp IS enforced at compile time
try do
  Code.compile_string("defmodule Ctl do\n def go, do: Acme.Orders.Internal.Pricing.secret(1)\nend")
  IO.puts("control: defp call accepted (UNEXPECTED)")
rescue
  e -> IO.puts("control: defp call refused at runtime/compile: " <> inspect(e.__struct__))
end
# compile-time warning on private-call-by-remote:
