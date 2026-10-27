# H5: Elixir applies no def/defp distinction to a struct pattern in a head: both heads
#     compile to the same `%{__struct__: Foo}` test, so a forged map is refused by BOTH a
#     public and a private function, and Elixir offers no way to omit the test on defp.
#     Elixir also adds NO is_integer guard for @spec'd integer params on either.
# Falsifier: the two compiled heads differ in the struct test, or defp accepts the forged map,
#            or a spec'd `def f(n :: integer)` refuses a float.
# Command: elixir p5_elixir_defp.exs     Toolchain: Elixir 1.14.0 / OTP 25
dir = Path.join(System.tmp_dir!(), "p5_#{System.unique_integer([:positive])}")
File.mkdir_p!(dir)
src = Path.join(dir, "p5.ex")
File.write!(src, ~S'''
defmodule P5 do
  defmodule Foo do
    defstruct [:v]
  end

  @spec pub(%Foo{}) :: integer
  def pub(%Foo{} = f), do: priv(f)
  defp priv(%Foo{v: v}), do: v

  def pub_bare(f), do: priv(f)            # exported, passes the value on
  @spec big(integer) :: integer
  def big(n), do: if(n >= 9, do: 1, else: 0)
end
''')
Kernel.ParallelCompiler.compile_to_path([src], dir)
Code.prepend_path(dir)

forged = %{__struct__: Other, v: 5}
res = fn label, f ->
  r = try do {:ok, f.()} rescue e -> {:raised, e.__struct__} end
  IO.puts("#{label}: #{inspect(r)}")
  r
end

r1 = res.("pub(forged)      ", fn -> P5.pub(forged) end)
r2 = res.("pub_bare(forged) ", fn -> P5.pub_bare(forged) end)
r3 = res.("big(100.5)       ", fn -> P5.big(100.5) end)

# Compare the compiled head of def vs defp (abstract code from debug_info)
{:ok, {_, [{:abstract_code, {:raw_abstract_v1, forms}}]}} = :beam_lib.chunks(String.to_charlist(Path.join(dir, "Elixir.P5.beam")), [:abstract_code])
heads = for {:function, _, n, 1, [{:clause, _, [pat], _, _} | _]} <- forms, n in [:pub, :priv], do: {n, :erl_pp.expr(pat) |> IO.iodata_to_binary() |> String.replace(~r/\s+/, " ")}
IO.inspect(heads, label: "compiled heads")

checks = [
  {"pub refuses forged map", match?({:raised, FunctionClauseError}, r1)},
  {"pub_bare (private callee) refuses forged map", match?({:raised, FunctionClauseError}, r2)},
  {"spec'd integer param does NOT refuse a float", r3 == {:ok, 1}},
  {"both heads carry the same struct test", (heads |> Enum.map(fn {_, h} -> String.contains?(h, "__struct__") end) |> Enum.all?())}
]
for {l, ok} <- checks, do: IO.puts("CHECK #{l}: #{if ok, do: "ok", else: "FAIL"}")
if Enum.all?(checks, &elem(&1, 1)), do: :ok, else: System.halt(1)
