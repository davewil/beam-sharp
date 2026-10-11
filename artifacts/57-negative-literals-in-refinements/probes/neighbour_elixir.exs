# Elixir: -5 is the unary-op AST, never a literal; the guard and pattern machinery fold it later.
# Run: source env.sh; elixir neighbour_elixir.exs
show = fn tag, src -> IO.puts(String.pad_trailing(tag, 12) <> String.pad_trailing(src, 30) <> " => " <> inspect(Code.string_to_quoted!(src, columns: false))) end
for s <- ["-5", "- 5", "-(5)", "-(-5)", "0 - 5", "-0"], do: show.("expr", s)
show.("guard", "def f(x) when x >= -5, do: x")
show.("pattern", "def f(-5), do: :a")
show.("pattern", "case y do -5 -> :a end")
IO.puts("--- do they compile? (pattern with literal, guard with literal, guard with arithmetic)")
mod = """
defmodule M do
  def f(-5), do: :lit
  def f(x) when x >= -(2 + 3), do: :arith_guard
  def f(_), do: :other
end
"""
IO.inspect(Code.eval_string(mod) |> elem(0) |> then(fn {:module, m, _, _} -> {m.f(-5), m.f(0), m.f(-9)} end))
IO.puts("--- the expanded (post-expansion) form of -5 in a pattern: folded?")
{:ok, q} = Code.string_to_quoted("fn -5 -> :a end")
IO.inspect(Macro.expand(q, __ENV__) |> Macro.to_string())
# Negative control: a pattern that is NOT a constant expression must be refused
IO.puts("--- control: -x in a pattern must be refused")
try do
  Code.eval_string("case 1 do -x -> 1 end")
  IO.puts("ACCEPTED (control failed)")
rescue _ -> IO.puts("refused, as it should be")
end
