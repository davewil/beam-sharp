# usage: elixir forge.exs OUTDIR  -- an Elixir caller (map literal with atom keys, as a decoded payload would be)
[dir] = System.argv()
true = :code.add_patha(String.to_charlist(dir))
{:module, :Forge} = :code.load_file(:Forge)
inv  = %{Kind: :"Forge.Invoice", Id: 1, Total: 999}
cart = %{Kind: :"Forge.Cart", Item: inv, N: 1}
for {name, f} <- [
  {"ViaCart(%{Item: Invoice 999})", fn -> apply(:Forge, :ViaCart, [cart]) end},
  {"InlineCart(%{Item: Invoice 999})", fn -> apply(:Forge, :InlineCart, [cart]) end},
  {"ViaOctets([100.5])", fn -> apply(:Forge, :ViaOctets, [[100.5]]) end}
] do
  r = try do {:returned, f.()} rescue e -> {:error, e.__struct__} end
  IO.puts("  #{String.pad_trailing(name, 40)} => #{inspect(r)}")
end
