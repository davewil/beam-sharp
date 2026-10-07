defmodule Shop.Orders do
  @moduledoc "orders"
  def total(x), do: Shop.Orders.Cache.get(x)
end
