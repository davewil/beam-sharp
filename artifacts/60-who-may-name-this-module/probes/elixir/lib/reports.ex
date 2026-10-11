defmodule Shop.Reports do
  def report(n), do: Shop.Orders.recompute_total(n)
end
