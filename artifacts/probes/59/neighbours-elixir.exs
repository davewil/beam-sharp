# Elixir 1.14: does `def` vs `defp` change any compiler-inserted check? @spec is documentation to the compiler.
defmodule N do
  @spec outer(0..255) :: integer
  def outer(n), do: bump(n)
  @spec bump(0..255) :: integer
  defp bump(n), do: n + 1
  @spec outer_l([0..255]) :: integer
  def outer_l(xs), do: Enum.sum(Enum.map(xs, &bump/1))
end
IO.inspect(N.outer(1.5), label: "outer(1.5)   def, @spec 0..255")
IO.inspect(N.outer(300), label: "outer(300)   def, @spec 0..255")
IO.inspect(N.outer_l([1.5, 300]), label: "outer_l([1.5,300]) -> defp bump")
