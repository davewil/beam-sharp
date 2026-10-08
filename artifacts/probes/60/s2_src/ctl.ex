defmodule Ctl do
  def go, do: Acme.Orders.Internal.Pricing.secret(1)
end
