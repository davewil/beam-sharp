{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(~c"ebin/Elixir.Probe59.beam", [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, Probe59, data, [])
for {:function, _, name, arity, clauses} <- forms, name not in [:__info__, :module_info] do
  IO.puts(:erl_pp.function({:function, 0, name, arity, clauses}))
end
