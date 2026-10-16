# 62 / P1 — which spellings of a PascalCase remote call does Elixir's parser accept?
# Parses each candidate source with Code.string_to_quoted and, where it parses, evaluates it
# against a module exporting 'New'/1 and new/1 (built by p0_mk.erl, same shape bsc emits).
cands = [
  ":Shop.New(1)", ":\"BSharp.Shop\".New(1)", ":\"Shop.Reports\".Totals(1)",
  ":\"Elixir.Shop\".New(1)", ":Shop.\"New\"(1)", ":Shop.new(1)", "apply(:Shop, :New, [1])",
  "Kernel.apply(:Shop, :New, [1])", ":erlang.apply(:Shop, :New, [1])"
]
for c <- cands do
  case Code.string_to_quoted(c) do
    {:ok, _} ->
      r = try do
            {v, _} = Code.eval_string(c); inspect(v)
          rescue e -> "RUNTIME " <> inspect(e.__struct__)
          end
      IO.puts(String.pad_trailing(c, 36) <> " parses -> " <> r)
    {:error, {_, msg, tok}} -> IO.puts(String.pad_trailing(c, 36) <> " SYNTAX_ERROR (" <> inspect(msg) <> tok <> ")")
  end
end
