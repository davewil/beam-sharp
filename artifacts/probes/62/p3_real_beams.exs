# 62 / P3 — Elixir against REAL bsc-emitted beams (examples/Shop), not a hand-built stand-in.
Code.prepend_path(System.get_env("P62OUT"))
try_it = fn label, src ->
  case Code.string_to_quoted(src) do
    {:error, _} -> IO.puts("  #{String.pad_trailing(label, 44)} SYNTAX_ERROR")
    {:ok, _} ->
      r = try do {v, _} = Code.eval_string(src); inspect(v) rescue e -> "RAISED " <> inspect(e.__struct__) end
      IO.puts("  #{String.pad_trailing(label, 44)} #{r}")
  end
end
IO.puts("exports of :Shop (from the beam):")
IO.inspect(:Shop.module_info(:exports) |> Enum.reject(&(elem(&1, 0) in [:module_info])), limit: :infinity)
try_it.(":Shop.New(1)", ":Shop.New(1)")
try_it.(~s|:Shop."New"(1)  (quoted function name)|, ~s|:Shop."New"(1)|)
try_it.("apply(:Shop, :New, [1])", "apply(:Shop, :New, [1])")
try_it.(":Shop.new(1)  (snake alias; absent today)", ":Shop.new(1)")
try_it.(~s|Record in: :Shop."Which"(%{Kind: :"Shop.Order", Id: 1, Total: 2})|, ~s|:Shop."Which"(%{Kind: :"Shop.Order", Id: 1, Total: 2})|)
try_it.(~s|Elixir struct in: :Shop."Which"(%URI{})|, ~s|:Shop."Which"(%URI{})|)
