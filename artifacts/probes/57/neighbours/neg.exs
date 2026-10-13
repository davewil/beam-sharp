IO.inspect(Code.string_to_quoted!("-5"), label: "elixir AST of -5 (unary op node?)")
IO.inspect(Code.string_to_quoted!("x >= -5"), label: "elixir guard comparand")
IO.inspect(Macro.expand(quote(do: -5), __ENV__), label: "expanded")
defmodule G do
  def f(n) when n >= -5, do: :ok
  def f(-7), do: :seven
  def f(_), do: :no
end
IO.inspect({G.f(-3), G.f(-7), G.f(-9)}, label: "elixir runtime")
