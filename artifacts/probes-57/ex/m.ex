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
