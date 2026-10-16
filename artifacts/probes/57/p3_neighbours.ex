defmodule N57 do
  @type delta :: -100..100
  @spec f(delta) :: -1 | 0 | 1
  def f(x) when x < -1, do: -1
  def f(x) when x >= -1, do: 0
end
