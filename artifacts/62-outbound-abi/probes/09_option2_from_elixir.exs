Code.prepend_path(System.get_env("BS_EBIN"))
show = fn label, src ->
  r = try do {v, _} = Code.eval_string(src); inspect(v) rescue e -> "RAISES #{inspect(e.__struct__)}" end
  IO.puts(String.pad_trailing(label, 22) <> String.pad_trailing(src, 48) <> r)
end
show.("plain dot, snake", ":Abi.new_http(41)")
show.("record via alias", ":Abi.make_point(3)")
show.("PascalCase still", ~S|:Abi."NewHTTP"(41)|)
show.("import + bare call", "import :Abi, only: [new_http: 1]; new_http(1)")
show.("pipe", "41 |> :Abi.new_http()")
show.("capture", "Enum.map([1,2], &:Abi.new_http/1)")
show.("NEGATIVE: no alias built", ":Abi.NoSuchAlias(1)")
IO.puts("module_info(:exports) count: #{length(:Abi.module_info(:exports))}")
