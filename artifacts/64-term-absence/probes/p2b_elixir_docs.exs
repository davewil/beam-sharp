# p2b: pull the shipped docs of Map.fetch/2, Map.get/3 and Access.get/3 from the installed
# Elixir 1.14.0 beam docs chunk (sources are not installed; only ebin). Run:
#   elixir p2b_elixir_docs.exs > p2b_elixir_docs.out ; exit 1 if the docs no longer mention the nil ambiguity.
{:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Map)
pick = fn name, ar -> Enum.find(docs, fn {{:function, n, a}, _, _, _, _} -> n == name and a == ar; _ -> false end) end
{_, _, _, %{"en" => fetch_doc}, _} = pick.(:fetch, 2)
{_, _, _, %{"en" => get_doc}, _} = pick.(:get, 3)
IO.puts("--- Map.fetch/2 ---\n" <> String.slice(fetch_doc, 0, 400))
IO.puts("--- Map.get/3 ---\n" <> String.slice(get_doc, 0, 600))
ok = String.contains?(get_doc, "nil") or String.contains?(get_doc, "default")
IO.puts("ASSERT docs mention default/nil semantics: " <> if(ok, do: "holds", else: "FAILS"))
if ok, do: System.halt(0), else: System.halt(1)
