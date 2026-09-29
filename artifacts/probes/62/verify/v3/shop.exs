Code.prepend_path("shop")
for s <- [":Shop.New(1)", ~S|:"BSharp.Shop".New(1)|, ~S|:"Shop.Reports".Totals(1)|, ~S|:"Elixir.Shop".New(1)|, ~S|:"BSharp.Shop".new(1)|, "apply(:Shop, :New, [1])", ~S|:Shop."New"(1)|] do
  p = case Code.string_to_quoted(s) do {:ok,_} -> "parses"; _ -> "SYNTAX_ERROR" end
  r = if p == "parses" do try do {v,_} = Code.eval_string(s); inspect(v) rescue e -> "raised " <> inspect(e.__struct__) end else "-" end
  IO.puts(s <> " -> " <> p <> " | " <> r)
end
