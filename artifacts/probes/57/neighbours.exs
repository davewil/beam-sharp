for s <- ["-5", "- 5", "-(-5)", "0 - 5", "2 + 3", "x >= -5"] do
  IO.puts("#{String.pad_trailing(s, 8)} -> #{inspect(Code.string_to_quoted!(s))}")
end
IO.puts("pattern/guard use:")
defmodule G do
  def f(x) when x >= -5, do: :a
  def f(-6), do: :lit
  def g(x) when x >= 2 + 3, do: :ok   # arithmetic in a guard is real expression
  def g(_), do: :no
end
IO.inspect({G.f(-5), G.f(-6), G.g(5)})
IO.inspect(quote(do: unquote(-5)) , label: "quote of integer -5")
