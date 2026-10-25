{:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Kernel)
for {{:macro, :is_struct, a}, _, _, %{"en" => d}, _} <- docs, do: IO.puts("is_struct/#{a}:\n#{d}\n")
