[{M, bin}] = Code.compile_string("""
defmodule M do
  def f(-5), do: :neg5
  def g(x) when x >= -5, do: :ok
  def g(_), do: :no
  def h(x), do: x - -5 + -x
end
""")
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, M, data, [])
for {:function, _, n, _, cl} <- forms, do: IO.inspect(cl, label: to_string(n), limit: :infinity)
IO.inspect(Macro.expand(quote(do: -5), __ENV__), label: "expand")
IO.inspect(Macro.expand(quote(do: -5), __ENV__) == -5)
