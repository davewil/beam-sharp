# Elixir: (1) abstract code it hands to the Erlang compiler for wrap/1 and spin/4; (2) {tr,..} count in the emitted beam
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks('Elixir.BenchEx.beam', [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, :"Elixir.BenchEx", data, [])
for {:function, _, n, a, cs} <- forms, n in [:wrap, :spin] do
  IO.puts("--- #{n}/#{a}")
  IO.puts(:erl_pp.form({:function, 0, n, a, cs}) |> IO.iodata_to_binary())
end
specs = for {:attribute, _, :spec, {{n, a}, _}} <- forms, do: {n, a}
IO.inspect(specs, label: "specs emitted")
IO.inspect(Enum.filter(forms, &match?({:attribute, _, :compile, _}, &1)), label: "compile attrs")
{:beam_file, _, _, _, _, fs} = :beam_disasm.file('Elixir.BenchEx.beam')
count = fn
  {:tr, _, _}, _ -> 1
  t, f when is_tuple(t) -> t |> Tuple.to_list() |> Enum.map(&f.(&1, f)) |> Enum.sum()
  l, f when is_list(l) -> l |> Enum.map(&f.(&1, f)) |> Enum.sum()
  _, _ -> 0
end
IO.inspect(for({:function, n, a, _, is} <- fs, n in [:spin, :wrap], do: {n, a, count.(is, count)}), label: "{tr,..} operands per fn")
