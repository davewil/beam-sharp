# p18: Elixir's one source-level dependency declaration is Mix.install/2 (scripts).  Sources are not installed on this
# machine (only ebin/), so the evidence is the docs chunk compiled into Mix's beam, quoted verbatim, plus the exported arity.
{:docs_v1, _, _, _, %{"en" => moduledoc}, _, docs} = Code.fetch_docs(Mix)
_ = moduledoc
{_, _, _, %{"en" => doc}, _} = Enum.find(docs, fn {{:function, :install, 2}, _, _, _, _} -> true; _ -> false end)
doc |> String.split("\n") |> Enum.take(12) |> Enum.join("\n") |> IO.puts()
IO.puts("...")
Code.ensure_loaded(Mix)
IO.inspect(function_exported?(Mix, :install, 2), label: "Mix.install/2 exported")
