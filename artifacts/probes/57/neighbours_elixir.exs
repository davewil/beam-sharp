IO.inspect(Code.string_to_quoted!("x >= -5"), label: "elixir ast")
IO.inspect(Code.string_to_quoted!("-5"), label: "elixir -5")
IO.inspect(Code.string_to_quoted!("- 5"), label: "elixir '- 5'")
defmodule G do
  defguard small(x) when x >= -5 and x <= 5
  def f(x) when small(x), do: :in
  def f(_), do: :out
end
IO.inspect({G.f(-5), G.f(-6)}, label: "elixir guard on -5")
