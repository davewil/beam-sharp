defmodule Shop.Orders do
  def total(x), do: Shop.Orders.Internal.recompute(x)
end
