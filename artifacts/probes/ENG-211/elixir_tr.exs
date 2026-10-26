# Does Elixir's own front end hand beam_ssa_type enough to keep the operand ranges?
# Compile aoc/bench/bench_ex.ex, pull the abstract code Elixir emitted back out of the
# .beam's debug_info, and ask the Erlang compiler for the assembly ('S').
[out, src] = System.argv()
File.mkdir_p!(out)
Code.compiler_options(debug_info: true)
[{mod, bin}] = Code.compile_file(src) |> Enum.filter(fn {m, _} -> m == BenchEx end)
File.write!(Path.join(out, "BenchEx.beam"), bin)
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, mod, data, [])
abstr = Path.join(out, "Elixir.BenchEx.abstr")
File.write!(abstr, ["%% coding: latin-1\n" | Enum.map(forms, &:io_lib.format(~c"~p.~n", [&1]))])
{:ok, _} = :compile.file(String.to_charlist(abstr), [:from_abstr, :S, outdir: String.to_charlist(out)])
IO.puts("wrote #{Path.join(out, "Elixir.BenchEx.S")}")
