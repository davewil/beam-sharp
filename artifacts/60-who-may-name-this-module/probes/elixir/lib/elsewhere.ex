defmodule Elsewhere do
  # unrelated module calls @doc false fn of a @moduledoc false module
  def poke(n), do: Shop.Orders.recompute_total(n)
  def old(n), do: Shop.Orders.old_total(n)
end
