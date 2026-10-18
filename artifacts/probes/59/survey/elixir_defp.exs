# S-EX — what does Elixir put at a defp / def entry?  Only what the programmer wrote.
# (a) a @spec'd struct parameter with no pattern -> no check at def OR defp
# (b) a %S{} pattern in a defp head -> the check exists, because it is a pattern
# (c) @doc false does not change emitted code (it is documentation, not visibility)
defmodule S do
  defstruct [:id, :total]
end

mods = Code.compile_string("""
defmodule X do
  @spec pub_spec(%S{}) :: integer
  def pub_spec(o), do: priv_spec(o)
  @spec priv_spec(%S{}) :: integer
  defp priv_spec(o), do: o.total

  def pub_pat(o), do: priv_pat(o)
  defp priv_pat(%S{} = o), do: o.total

  @doc false
  def hidden(o), do: o.total
  def shown(o), do: o.total
end
""")
{X, bin} = Enum.find(mods, fn {m, _} -> m == X end)
{:beam_file, _, _, _, _, fns} = :beam_disasm.file(bin)
for {:function, name, 1, _, code} <- fns, name in [:pub_spec, :priv_spec, :pub_pat, :priv_pat, :hidden, :shown] do
  tests = for i <- code, is_tuple(i), elem(i, 0) in [:test, :select_val, :get_map_elements, :is_struct], do: elem(i, 0)
  has_struct_test = Enum.any?(code, fn i -> is_tuple(i) and inspect(i) =~ "S" and elem(i,0) in [:test, :get_map_elements, :select_val] end)
  IO.puts("#{String.pad_trailing(to_string(name), 10)} instrs=#{length(code)}  struct-tag test: #{has_struct_test}")
end
IO.puts("--- priv_pat asm:")
for {:function, :priv_pat, 1, _, code} <- fns, do: Enum.each(code, &IO.inspect(&1, limit: 8))
