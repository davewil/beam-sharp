# Side finding: the record FIELD keys are PascalCase atoms too (%{Id: 1}).
# Does Elixir's dot field access reach them?  Run: elixir p2b_field_access.exs
cls = fn src ->
  case Code.string_to_quoted(src) do
    {:error, _} -> :syntax_error
    {:ok, _ast} ->
      try do
        {v, _} = Code.eval_string(src, [o: %{Id: 7, Kind: :"Shop.Order"}]); {:ok, v}
      rescue e -> {:raised, e.__struct__}   # CompileError for invalid alias
      end
  end
end
res = for s <- ["o.Id", ~S|o."Id"|, "o[:Id]", "Map.fetch!(o, :Id)", "%{Id: i} = o; i"], do: {s, cls.(s)}
for {s, r} <- res, do: IO.puts(String.pad_trailing(s, 24) <> inspect(r))
# assertion: at least one spelling must work (else the probe is vacuous) and o.Id must be observed, not assumed
System.halt(if Enum.any?(res, &match?({_, {:ok, 7}}, &1)), do: 0, else: 1)
