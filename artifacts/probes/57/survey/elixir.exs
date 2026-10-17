# Elixir 1.14: how a negative literal reaches the compiler, in expression / pattern / guard position.
for {label, src} <- [{"expr  -5", "-5"}, {"expr  - 5", "- 5"}, {"expr  -(5)", "-(5)"}, {"expr  2 + 3", "2 + 3"},
                      {"pattern -5", "case x do -5 -> 1 end"}, {"guard x >= -5", "def f(x) when x >= -5, do: x"}] do
  IO.inspect(Code.string_to_quoted!(src), label: String.pad_trailing(label, 16))
end
IO.puts("--5 : " <> (try do Code.string_to_quoted!("--5"); "parses" rescue e in SyntaxError -> "SyntaxError (`--` is the list-subtract operator)" end))
src = """
defmodule P57.M do
  def f(x) when x >= -5 and x <= 2 + 3, do: :in
  def f(_), do: :out
  def g(-5), do: :neg
  def g(_), do: :other
  @c -5
  def h(x) when x >= @c, do: :ok
  def h(_), do: :no
end
"""
Code.compile_string(src)
IO.inspect({P57.M.f(-5), P57.M.f(-6), P57.M.f(5), P57.M.f(6), P57.M.g(-5), P57.M.h(-5)}, label: "behaviour (expected {:in,:out,:in,:out,:neg,:ok})")
