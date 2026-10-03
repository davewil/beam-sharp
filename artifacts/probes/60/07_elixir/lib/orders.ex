defmodule Acme.Orders do
  # An outsider names the @moduledoc false module and the @doc false function.
  def total(c), do: Acme.Billing.Internal.Ledger.post(c) + Acme.Billing.sneaky(c)
end
