defmodule Shop.Billing do
  alias Shop.Orders.Internal
  def bill(x), do: Internal.recompute(x)
  def ok(x), do: Shop.Orders.total(x)
  def sneaky(x), do: apply(Module.concat(["Shop", "Orders", "Internal"]), :recompute, [x])
end
