defmodule Shop.Orders do
  @moduledoc false

  def apply_order(n), do: recompute_total(n) + 1

  # public in the BEAM sense, hidden from docs
  @doc false
  def recompute_total(n), do: n * 2

  @deprecated "use apply_order/1"
  def old_total(n), do: n

  defp hidden(n), do: n
  def uses_hidden(n), do: hidden(n)
end
