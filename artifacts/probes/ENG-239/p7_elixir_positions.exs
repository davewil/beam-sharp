# P7: added after the verifier found p3 never printed the pattern position. Which BEAM abstract form Elixir 1.14 emits for -5 in a guard, pattern and body.
IO.inspect(Macro.expand(quote(do: -x), __ENV__), label: "expand -x")
IO.inspect(Macro.expand(quote(do: -(5)), __ENV__), label: "expand -(5)")
IO.inspect(Macro.expand(quote(do: +5), __ENV__), label: "expand +5")
IO.inspect(Macro.expand(quote(do: -5.0), __ENV__), label: "expand -5.0")
IO.inspect(Macro.expand(quote(do: 0 - 5), __ENV__), label: "expand 0-5")
{{:module, _, bin, _}, _} = Code.eval_string("""
defmodule R do
  def a(x) when x >= -5, do: 1
  def neg(x) when x >= unquote(-5), do: 1
  def p(-5), do: 1
  def f(), do: -5
  def g(x), do: x - 5
end
""")
{:ok, {_, [abstract_code: {:raw_abstract_v1, forms}]}} = :beam_lib.chunks(bin, [:abstract_code])
for {:function, _, n, _, [{:clause, _, h, g, b} | _]} <- forms, n in [:a,:lit,:neg,:p,:f,:g] do
  IO.puts("#{n}: head=#{inspect h} guard=#{inspect g} body=#{inspect b}")
end
