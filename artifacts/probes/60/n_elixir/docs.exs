# EXPECTED (before run): Module's own docs describe `@moduledoc false` as hiding
# from documentation, and Mix.Tasks.Xref documents modes that REPORT edges
# (callers, trace, graph) with no mode that FORBIDS one.
{:docs_v1, _, _, _, %{"en" => d}, _, _} = Code.fetch_docs(Module)
d |> String.split("\n") |> Enum.with_index(1)
  |> Enum.filter(fn {l, _} -> String.contains?(l, "moduledoc false") end)
  |> Enum.each(fn {l, i} -> IO.puts("Module doc line #{i}: #{String.trim(l)}") end)
{:docs_v1, _, _, _, %{"en" => x}, _, _} = Code.fetch_docs(Mix.Tasks.Xref)
modes = Regex.scan(~r/^## mix xref (\w+)/m, x) |> Enum.map(&List.last/1)
IO.puts("xref modes: #{Enum.join(modes, ", ")}")
IO.puts("xref doc mentions forbid/restrict/boundary: #{Regex.match?(~r/forbid|restrict|boundary|not allowed/i, x)}")
