Code.prepend_path(System.get_env("BS_EBIN"))
forms = [
  ~S|:Shop.New(1)|, ~S|Shop.New(1)|, ~S|:"Elixir.Shop".new(1)|, ~S|:"Elixir.Shop".New(1)|,
  ~S|:Shop.new(1)|, ~S|:"Shop".New(1)|,
  ~S|:Shop."New"(1)|, ~S|:"Shop"."New"(1)|, ~S|Shop."New"(1)|, ~S|:Shop.'New'(1)|,
  ~S|apply(:Shop, :New, [1])|, ~S|Kernel.apply(:Shop, :New, [1])|, ~S|:erlang.apply(:Shop, :New, [1])|,
  ~S|&:Shop.New/1|, ~S|&:Shop."New"/1|, ~S|&:erlang.apply(:Shop, :New, &1)|,
  ~S|Module.concat(:Shop, nil).New(1)|, ~S|m = :Shop; m.New(1)|, ~S|m = :Shop; m."New"(1)|,
  ~S|(&:Shop.new/1)|, ~S|:Shop.New|,~S|:Shop.New.(1)|,
  ~S|:Shop.\New(1)|,
]
IO.puts("== parse level (Code.string_to_quoted) and AST")
for s <- forms do
  case Code.string_to_quoted(s) do
    {:ok, ast} -> IO.puts(String.pad_trailing(s, 44) <> "parses  " <> inspect(ast))
    {:error, {_, msg, tok}} -> IO.puts(String.pad_trailing(s, 44) <> "SYNTAX_ERROR  " <> inspect(msg) <> inspect(tok))
  end
end
IO.puts("\n== run level (only forms that parse)")
for s <- forms do
  with {:ok, _} <- Code.string_to_quoted(s) do
    r = try do
      {v, _} = Code.eval_string(s); {:ok, v}
    rescue e -> {:raised, e.__struct__, Exception.message(e) |> String.slice(0,80)}
    end
    IO.puts(String.pad_trailing(s, 44) <> inspect(r))
  end
end
IO.puts("\n== tokenizer level")
for s <- [~S|:Shop.New(1)|, ~S|:Shop."New"(1)|, ~S|:Shop.new(1)|] do
  IO.puts(s <> " -> " <> inspect(:elixir_tokenizer.tokenize(String.to_charlist(s), 1, 1, []) |> elem(0) |> then(&(&1)), limit: :infinity))
end
