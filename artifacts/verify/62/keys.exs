Code.prepend_path("eb")
o = :Shop."New"(1)
cs = ["o.Total", "o.\"Total\"", "o[:Total]", "%{Total: t} = o; t", "Map.fetch!(o, :Total)", "import :Shop, only: [{:New, 1}]; New(1)", "import :Shop, only: [{:New, 1}]; \"New\"(1)"]
for c <- cs do
  r = try do {v, _} = Code.eval_string(c, [o: o]); "ok -> #{inspect v}" rescue e -> "#{inspect e.__struct__}: #{String.slice(Exception.message(e),0,60) |> String.replace("\n"," ")}" end
  IO.puts("#{String.pad_trailing(c, 46)} #{r}")
end
