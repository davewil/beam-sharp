defmodule Shop.Orders.Internal.Helper do
  @moduledoc false
  def recompute(x), do: x * 2
end
defmodule Shop.Orders do
  def total(x), do: Shop.Orders.Internal.Helper.recompute(x)
end
defmodule Shop.Orders.Apply do
  def go(x), do: Shop.Orders.Internal.Helper.recompute(x) + 1
end
