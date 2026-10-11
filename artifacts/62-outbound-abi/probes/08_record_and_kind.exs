# Probe 08 -- re-measures ticket 62 frictions 2 and 3 (record is a map, Kind tag required) with the current compiler.
Code.prepend_path(System.get_env("BS_EBIN"))
p = fn l, v -> IO.puts("  " <> String.pad_trailing(l, 44) <> inspect(v)) end
run = fn l, f ->
  r = try do f.() rescue e -> {:raised, e.__struct__} catch k, v -> {k, v} end
  IO.puts("  " <> String.pad_trailing(l, 44) <> inspect(r))
end
IO.puts("(a) exports as Elixir sees them:")
p.("Shop exports", :Shop.module_info(:exports) |> Enum.reject(&(elem(&1, 0) == :module_info)) |> Enum.sort())
order = :Shop."New"(7)
IO.puts("(b) a B# record arrives as:")
p.("value", order)
p.("is_struct?", is_struct(order))
p.("map pattern %{Kind: :\"Shop.Order\", Id: id}", (case order do %{Kind: :"Shop.Order", Id: id} -> {:matched, id}; _ -> :no end))
IO.puts("(c) handing values back (right tag / wrong tag / struct), via the quoted call:")
run.("right tag", fn -> :Shop."Which"(%{Kind: :"Shop.Order", Id: 9, Total: 5}) end)
run.("wrong tag", fn -> :Shop."Which"(%{Kind: :"MyApp.Order", Id: 9, Total: 5}) end)
run.("Elixir struct, same fields", fn -> :Shop."Which"(%{__struct__: MyOrder, Id: 9, Total: 5}) end)
run.("NEGATIVE CONTROL: right tag, missing Total", fn -> :Shop."Which"(%{Kind: :"Shop.Order", Id: 9}) end)
