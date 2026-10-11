# Elixir's .ex sources are not in the conda package; the Dbgi chunk of Elixir.Macro.beam has the
# abstract code WITH original line numbers. Print the underscore functions and their source lines.
beam = :code.which(Macro)
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(beam, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, Macro, data, [])
file = for {:attribute, _, :file, {f, _}} <- forms, do: List.to_string(f)
IO.puts("source file recorded in debug info: #{inspect(Enum.uniq(file))}")
for {:function, line, name, arity, _} = f <- forms, name in [:underscore, :"-underscore/1-fun-0-", :camelize] or String.contains?(Atom.to_string(name), "underscore") do
  IO.puts("\n== #{name}/#{arity} defined at Elixir source line #{inspect(line)}")
  IO.puts(:erl_pp.form(f))
end
IO.puts("\n== Macro.underscore behaviour, executed:")
for s <- ["New", "NewHTTP", "ParseURL", "HTTPServer", "XMLHttpRequest", "ToJson", "Shop.Reports", "V2Parse", "Parse2D", "OKResult"] do
  IO.puts("  #{String.pad_trailing(s, 16)} -> #{Macro.underscore(s)}")
end
