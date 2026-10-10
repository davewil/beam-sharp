defmodule Shop.Orders do
  @moduledoc "client API"
  def total(c), do: Shop.Orders.Internal.recompute(c)
end

defmodule Shop.Orders.Internal do
  @moduledoc false
  def recompute(c), do: c + 100
end
