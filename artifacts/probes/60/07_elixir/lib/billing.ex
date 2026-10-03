defmodule Acme.Billing do
  def charge(c), do: Acme.Billing.Internal.Ledger.post(c)
  @doc false
  def sneaky(c), do: c + 1000
  defp round_(c), do: c
  def use_round(c), do: round_(c)
end

defmodule Acme.Billing.Internal.Ledger do
  @moduledoc false
  # Nesting by name only: Acme.Billing.Internal.Ledger is NOT lexically inside Acme.Billing.
  def post(c), do: c + 1
end
