defmodule Acme.Orders.Rules do
  @moduledoc false
  def recompute([]), do: 0
  def recompute([x | rest]), do: x + recompute(rest)
end

defmodule Acme.Orders do
  def total(xs), do: Acme.Orders.Rules.recompute(xs)
  defp secret, do: 1
  def reveal, do: secret()
end

defmodule Acme.Billing do
  # a SIBLING reaching into the helper: no error, no warning
  def invoice(xs), do: Acme.Orders.Rules.recompute(xs)
  # calling a defp from outside:
  def peek, do: Acme.Orders.secret()
end
