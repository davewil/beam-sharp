for s <- ["x >= -5", "-5", "x in -5..5", "x >= 2 - 7", "x >= - -5", "-x", "- 5", "-(5)"] do
  IO.puts("#{String.pad_trailing(s, 14)} #{inspect(Code.string_to_quoted!(s))}")
end
# do guards/patterns accept negatives & arithmetic? compile and look at erlang abstract
defmodule M do
  def g(x) when x >= -5 and x <= 5, do: :in
  def g(_), do: :out
  def h(x) when x >= 2 - 7, do: :ok
  def h(_), do: :no
  def p(-5), do: :m5
  def p(_), do: :o
  def r(x) when x in -5..5, do: :in
  def r(_), do: :out
end
IO.inspect({M.g(-5), M.g(-6), M.h(-5), M.h(-6), M.p(-5), M.r(-5), M.r(6)})
{:ok, {_, [abstract_code: {:raw_abstract_v1, ac}]}} = :beam_lib.chunks(:code.which(M) |> to_charlist, [:abstract_code]) |> then(fn {:ok, x} -> {:ok, x} end)
for {:function, _, n, _, cls} <- ac, n in [:g, :h, :r] do
  IO.inspect({n, Enum.map(cls, fn {:clause, _, _, guards, _} -> guards end)}, limit: :infinity)
end
IO.inspect(M.module_info(:compile))
