defmodule Web.Handler do
  def handle(c), do: Shop.Orders.Internal.recompute(c)
end
