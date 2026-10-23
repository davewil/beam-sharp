defmodule Line do
  @enforce_keys [:qty, :price]
  defstruct [:qty, :price]
end

defmodule Order do
  defstruct [:id, lines: []]
end

defmodule Nested do
  # Exported: struct pattern in the head -> tag check written by the author.
  def total(%Order{lines: ls}), do: sum(ls)

  # Private, struct pattern (author wrote it) vs private with field access only.
  defp sum([]), do: 0
  defp sum([l | t]), do: line_total(l) + sum(t)

  defp line_total(%Line{qty: q, price: p}), do: q * p

  # same body, no struct pattern: field access on a plain map
  def total_unpatterned(%Order{lines: ls}), do: sum2(ls)
  defp sum2([]), do: 0
  defp sum2([l | t]), do: line_total2(l) + sum2(t)
  defp line_total2(l), do: l.qty * l.price
end

t = fn label, f ->
  r = try do {:ok, f.()} rescue e -> {:raised, e.__struct__} end
  IO.puts("  #{String.pad_trailing(label, 56)} -> #{inspect(r)}")
end

good  = %Line{qty: 2, price: 3}
forged = %{__struct__: Evil, qty: 2, price: 3}
plain  = %{qty: 2, price: 3}
t.("control: well-formed order",                       fn -> Nested.total(%Order{id: 1, lines: [good]}) end)
t.("forged element __struct__: Evil, struct-pattern priv", fn -> Nested.total(%Order{id: 1, lines: [forged]}) end)
t.("forged element, private reads fields only",        fn -> Nested.total_unpatterned(%Order{id: 1, lines: [forged]}) end)
t.("plain map element, private reads fields only",     fn -> Nested.total_unpatterned(%Order{id: 1, lines: [plain]}) end)
t.("forged OUTER (exported struct pattern)",           fn -> Nested.total(%{__struct__: Evil, id: 1, lines: [good]}) end)
