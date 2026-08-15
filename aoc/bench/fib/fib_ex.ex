defmodule FibEx do
  def fib(n) when n <= 0, do: []
  def fib(n) when n > 0, do: series(n, 0, 1, [])

  defp series(n, _a, _b, acc) when n <= 0, do: reverse(acc, [])
  defp series(n, a, b, acc) when n > 0, do: series(n - 1, b, a + b, [a | acc])

  defp reverse([], acc), do: acc
  defp reverse([x | rest], acc), do: reverse(rest, [x | acc])
end
