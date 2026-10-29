defmodule Shop.Billing do
  def charge(x), do: Shop.Orders.Internal.recompute(x)
  def bad(x), do: Shop.Orders.Internal.hidden(x)
end
