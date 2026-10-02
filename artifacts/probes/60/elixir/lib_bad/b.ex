defmodule Shop.Reports do
  def r(x), do: Shop.Orders.Internal.Helper.recompute(x)
end
