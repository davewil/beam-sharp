defmodule Other do
  defstruct [:total]
end

defmodule P do
  defstruct [:total]

  # private, NO check at all: a forged struct/map sails through
  defp priv_bare(o), do: o.total
  # private, explicit struct pattern: the check the author writes by hand
  defp priv_pat(%__MODULE__{total: t}), do: t
  # private, explicit guard
  defp inc(n) when is_integer(n), do: n + 1
  defp inc_bare(n), do: n + 1

  def outer_bare(o), do: priv_bare(o)
  def outer_pat(o), do: priv_pat(o)
  def nested_pat(%{primary: p}), do: priv_pat(p)
  def nested_inc(%{count: c}), do: inc(c)
  def nested_inc_bare(%{count: c}), do: inc_bare(c)
end

r = fn label, f ->
  out = try do {:value, f.()} rescue e -> {:raised, e.__struct__, Map.get(e, :function)} end
  IO.puts("#{String.pad_trailing(label, 52)} -> #{inspect(out)}")
end

forged = %{__struct__: Other, total: 99}
r.("outer_bare(forged other struct)  [no check anywhere]", fn -> P.outer_bare(forged) end)
r.("outer_pat(forged other struct)   [hand-written pattern in defp]", fn -> P.outer_pat(forged) end)
r.("nested_pat(%{primary: forged})   [defp pattern catches nested]", fn -> P.nested_pat(%{primary: forged}) end)
r.("nested_inc(%{count: 1.5})        [defp guard catches nested float]", fn -> P.nested_inc(%{count: 1.5}) end)
r.("nested_inc_bare(%{count: 1.5})   [no guard: float flows]", fn -> P.nested_inc_bare(%{count: 1.5}) end)
