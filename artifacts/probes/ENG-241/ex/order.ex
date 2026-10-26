defmodule Order do
  @enforce_keys [:total]
  defstruct [:total]
end

defmodule Shop do
  def ship(%Order{} = o), do: inner(o)          # public, struct pattern
  def ship_loose(o), do: inner(o)               # public, no pattern: forwards to private
  defp inner(%Order{} = o), do: o.total         # PRIVATE with struct pattern
  defp inner_plain(o), do: o.total              # private, field access only
  def uses_plain(o), do: inner_plain(o)
end
