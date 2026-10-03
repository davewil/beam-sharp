defmodule Acme.Spy do
  # Calling a defp across modules.
  def peek(c), do: Acme.Billing.round_(c)
end
