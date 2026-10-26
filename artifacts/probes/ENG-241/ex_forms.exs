{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(~c"ex/Elixir.Shop.beam", [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, Shop, data, [])
for {:function, _, name, ar, clauses} <- forms, name in [:inner, :inner_plain, :ship, :ship_loose] do
  IO.puts("== #{name}/#{ar}")
  IO.puts(:erl_pp.form({:function, 0, name, ar, clauses}))
end
