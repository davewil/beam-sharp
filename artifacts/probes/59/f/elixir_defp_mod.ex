# the module under test (compiled by elixir_defp.exs)
defmodule Probe do
  defmodule Order,   do: (@enforce_keys [:id]; defstruct [:id, total: 0])
  defmodule Invoice, do: (@enforce_keys [:id]; defstruct [:id, total: 0])
  defmodule Cart,    do: defstruct [:item]

  def via_cart(%Cart{item: i}), do: amount(i)            # exported: only the Cart tag is tested
  def via_cart_raw(c), do: amount_raw(c.item)            # exported, no struct pattern at all
  defp amount(%Order{total: t}), do: t                   # private head with a struct pattern: tag IS tested
  defp amount_raw(o), do: o.total                        # private head without one: nothing tested
end

