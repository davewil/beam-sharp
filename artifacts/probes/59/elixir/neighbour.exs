# Probe 59g: Elixir 1.14.0. A struct pattern is the author's check; def and defp are treated identically.
# Is there any scope asymmetry between def and defp in what the compiler enforces? Executed, not asserted.
defmodule Order,   do: defstruct [:id, :total]
defmodule Invoice, do: defstruct [:id, :total]
defmodule Mod do
  def  pub(%Order{} = o),  do: priv(o)           # pattern on the exported head
  def  nested(%{item: i}), do: priv(i)           # forged struct nested in an unchecked map: no head pattern on the item
  def  mapped(xs),         do: Enum.map(xs, &priv/1)   # private captured as a fun
  def  leak(),             do: &priv/1                 # private fun escapes to a caller
  defp priv(%Order{total: t}), do: t             # pattern on the PRIVATE head
  defp loose(o),           do: o.total           # same body, no pattern: 'the body would not object'
  def  nested_loose(%{item: i}), do: loose(i)
end
forged = %{__struct__: Invoice, id: 1, total: 100}
t = fn label, f ->
  r = try do {:ok, f.()} rescue e -> {:raised, e.__struct__} end
  IO.puts(String.pad_trailing(label, 52) <> inspect(r))
end
t.("pub(forged)           [def head pattern]",            fn -> Mod.pub(forged) end)
t.("nested(%{item: forged}) [defp head pattern]",         fn -> Mod.nested(%{item: forged}) end)
t.("mapped([forged])        [defp via &priv/1]",          fn -> Mod.mapped([forged]) end)
t.("leak().(forged)         [escaped defp]",              fn -> Mod.leak().(forged) end)
t.("nested_loose(%{item: forged}) [defp, no pattern]",    fn -> Mod.nested_loose(%{item: forged}) end)
t.("pub(%Order{total: 5}) [control]",                     fn -> Mod.pub(struct(Order, id: 1, total: 5)) end)
IO.puts("--- compile-time: does 1.14 warn about a defp that accepts a wider type than its callers pass? (no type checker in 1.14)")
IO.puts("elixir " <> System.version())
