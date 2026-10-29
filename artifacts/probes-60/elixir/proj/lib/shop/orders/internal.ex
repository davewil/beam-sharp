defmodule Shop.Orders.Internal do
  @moduledoc false
  @doc false
  def recompute(x), do: x + 1
  defp hidden(x), do: x
  def via_hidden(x), do: hidden(x)
end
