# P3: how Elixir 1.14 represents and folds `-5` in expression, pattern, guard,
# defguard, and ranges. Everything printed is real output of this script.
IO.puts("== quoted AST")
for src <- ["x >= -5", "x >= 0 - 5", "x >= 2 + 3", "-5", "f(-5)"] do
  IO.puts("#{src}  =>  #{inspect(Code.string_to_quoted!(src))}")
end
IO.puts("\n== literal -5 in patterns / guards (compiled, then called)")
defmodule P do
  def pat(-5), do: :minus5
  def pat(_), do: :other
  def grd(x) when x >= -5 and x <= 5, do: :in
  def grd(_), do: :out
  def grd2(x) when x >= 2 + 3, do: :ge5
  def grd2(_), do: :lt5
  def rng(x) when x in -5..5, do: :in
  def rng(_), do: :out
  defguard is_delta(x) when is_integer(x) and x >= -100 and x <= 100
  def dg(x) when is_delta(x), do: :ok
  def dg(_), do: :no
end
IO.inspect({P.pat(-5), P.pat(5), P.grd(-5), P.grd(-6), P.grd2(5), P.grd2(4), P.rng(-5), P.rng(-6), P.dg(-100), P.dg(-101)}, label: "calls")
IO.puts("\n== pattern `-5..5` in a match (range literal with unary minus)")
IO.inspect(match?(-5..5, -5..5), label: "match?(-5..5, -5..5)")
IO.puts("\n== is `-5` folded at the parser, or later? Macro.expand / compile-time AST of the clause")
IO.inspect(quote(do: -5), label: "quote do: -5 (raw)")
IO.inspect(Macro.expand(quote(do: -5), __ENV__), label: "Macro.expand(quote do: -5)")
IO.inspect(is_integer(Macro.expand(quote(do: -5), __ENV__)), label: "  ...is an integer literal?")
IO.inspect(Macro.expand(quote(do: 2 + 3), __ENV__), label: "Macro.expand(quote do: 2 + 3)")
IO.puts("\n== the erlang forms Elixir emits for the guard (does Elixir fold before erlc?)")
{:ok, _, bin} = (
  {:ok, mod, bin, _} = Code.eval_string("""
  defmodule Q do
    def a(x) when x >= -5, do: 1
    def b(x) when x >= 2 + 3, do: 1
  end
  """) |> then(fn {{:module, m, b, _}, _} -> {:ok, m, b, nil} end)
  {:ok, mod, bin})
{:ok, {_, [abstract_code: {:raw_abstract_v1, forms}]}} = :beam_lib.chunks(bin, [:abstract_code])
for {:function, _, n, _, [{:clause, _, _, g, _} | _]} <- forms, n in [:a, :b] do
  IO.puts("#{n}: guard = #{inspect(g, limit: :infinity)}")
end
