# Source .ex files are not installed (only ebin/); the docs chunks of the installed beams are. Grep them for the idiom.
mods = for {m, _, _} <- :code.all_available() |> Enum.map(fn {a,b,c} -> {List.to_atom(a),b,c} end), String.starts_with?(Atom.to_string(m), "Elixir."), do: m
for m <- mods, match?({:docs_v1, _, _, _, _, _, _}, Code.fetch_docs(m)) do
  {:docs_v1, _, _, _, mdoc, _, docs} = Code.fetch_docs(m)
  texts = [(case mdoc do %{"en" => d} -> d; _ -> "" end) | for({_, _, _, %{"en" => d}, _} <- docs, do: d)]
  for t <- texts, line <- String.split(t, "\n"), line =~ ~r/is_struct\(.*\) or |module in \[|is_struct\(.*\) and |when .* in \[:/ do
    IO.puts("#{inspect(m)}: #{String.trim(line)}")
  end
end
