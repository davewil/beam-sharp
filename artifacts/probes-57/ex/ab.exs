{:ok, {_, [abstract_code: {:raw_abstract_v1, ac}]}} = :beam_lib.chunks('Elixir.M.beam', [:abstract_code])
for {:function, _, n, _, cls} <- ac, n in [:g, :h, :r, :p] do
  IO.inspect({n, Enum.map(cls, fn {:clause, _, h, guards, _} -> {h, guards} end)}, limit: :infinity)
end
