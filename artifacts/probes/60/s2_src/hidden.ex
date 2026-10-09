defmodule Acme.Orders.Internal.Pricing do
  @moduledoc false
  @doc false
  def compute(n), do: n * 2
  defp secret(n), do: n + 1
  def via(n), do: secret(n)
end

defmodule Acme.Billing do
  def due(n), do: Acme.Orders.Internal.Pricing.compute(n)   # compiles: no error, no warning
end
