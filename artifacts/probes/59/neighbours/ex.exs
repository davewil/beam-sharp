defmodule P do
  defmodule Inner, do: defstruct [:n]
  defmodule Outer, do: defstruct [:id, :inner]
  def via_private(%Outer{} = o), do: helper(o.inner)
  defp helper(%Inner{} = i), do: i.n
  defp helper_nomatch(i), do: i.n
  def via_nomatch(%Outer{} = o), do: helper_nomatch(o.inner)
end
forged = %{__struct__: P.Outer, id: 1, inner: %{__struct__: Other, n: 666}}
IO.inspect(try do P.via_private(forged) rescue e -> e.__struct__ end, label: "elixir defp with struct pattern, forged nested")
IO.inspect(P.via_nomatch(forged), label: "elixir defp without pattern, forged nested")
