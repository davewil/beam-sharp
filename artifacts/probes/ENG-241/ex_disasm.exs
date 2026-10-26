{:beam_file, _, _, _, _, fns} = :beam_disasm.file(~c"ex/Elixir.Shop.beam")
for {:function, :inner, 1, _, code} <- fns do
  IO.inspect(Enum.take(code, 8), limit: :infinity)
end
