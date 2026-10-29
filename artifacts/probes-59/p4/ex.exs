defmodule Ord do
  @enforce_keys [:amount]
  defstruct [:amount]
end
defmodule Shop do
  alias Ord, as: Order
  # user writes the struct pattern; the pattern IS the check, whether def or defp
  def pub_pat(o), do: priv_pat(o)
  defp priv_pat(%Order{} = o), do: o.amount
  def pub_bare(o), do: priv_bare(o)
  defp priv_bare(o), do: o.amount           # field access: crashes on non-map, accepts any map with :amount
  def pub_first([h | _]), do: priv_pat(h)   # depth-1 pass-through
  def pub_direct(%Order{} = o), do: o.amount
end

t = fn label, f ->
  r = try do {:returned, f.()} rescue e -> {:raised, e.__struct__} end
  IO.puts(String.pad_trailing(label, 44) <> inspect(r))
end
forged = %{__struct__: Quote, amount: "free"}
plain  = %{amount: "free"}
t.("def->defp %Order{}   forged(__struct__:Quote)", fn -> Shop.pub_pat(forged) end)
t.("def->defp %Order{}   plain map w/ :amount", fn -> Shop.pub_pat(plain) end)
t.("def->defp %Order{}   valid", fn -> Shop.pub_pat(struct!(Ord, amount: 1)) end)
t.("def->defp bare var   plain map", fn -> Shop.pub_bare(plain) end)
t.("def->defp bare var   forged struct", fn -> Shop.pub_bare(forged) end)
t.("pub_first([forged]) -> defp pattern", fn -> Shop.pub_first([forged]) end)
t.("enforce_keys: struct!(Order, [])", fn -> struct!(Ord, []) end)
t.("enforce_keys bypass via %{__struct__:}", fn -> Shop.pub_pat(%{__struct__: Ord, wrong_key: 1}) end)
