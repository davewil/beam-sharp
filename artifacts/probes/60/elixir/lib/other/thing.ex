defmodule Other.Thing do
  def go(x), do: Shop.Orders.Cache.get(x)
end
