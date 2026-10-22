Code.prepend_path(System.get_env("BS_EBIN"))
run = fn l, f ->
  r = try do inspect(f.()) rescue e -> "RAISED " <> inspect(e.__struct__) catch k, v -> "#{k} #{inspect v}" end
  IO.puts(String.pad_trailing(l, 44) <> r)
end
order = :Shop."New"(7)
run.("value", fn -> order end)
run.("is_struct", fn -> is_struct(order) end)
run.("has __struct__", fn -> Map.has_key?(order, :__struct__) end)
run.("map pattern %{Kind: :\"Shop.Order\", Id: id}", fn -> (case order do %{Kind: :"Shop.Order", Id: id} -> {:matched, id}; _ -> :no end) end)
run.("Which right tag", fn -> :Shop."Which"(%{Kind: :"Shop.Order", Id: 9, Total: 5}) end)
run.("Which wrong tag MyApp.Order", fn -> :Shop."Which"(%{Kind: :"MyApp.Order", Id: 9, Total: 5}) end)
run.("Which Elixir struct, same fields", fn -> :Shop."Which"(%{__struct__: MyOrder, Id: 9, Total: 5}) end)
run.("Which no Kind at all", fn -> :Shop."Which"(%{Id: 9, Total: 5}) end)
