cases = [
 ~S[:Shop."New"(1)],
 ~S[1 |> :Shop."New"() |> :Shop."Pay"()],
 ~S[&:Shop."New"/1],
 ~S[:Shop.'New'(1)],
 ~S[x = :Shop."New"(1)],
 ~S[:Shop. "New"(1)],
 ~S[:"Shop"."New"(1)],
 ~S[:Shop."New" (1)],
 ~S[:Shop."New"],
 ~S[m = :Shop; m."New"(1, 2)],
 ~S[:Shop."New"(1) |> then(&:Shop."Pay"/1)],
]
for c <- cases do
  {:ok, q} = try do Code.string_to_quoted(c) rescue e -> {:err, e} end
  fmt = try do Code.format_string!(c) |> IO.iodata_to_binary() rescue e -> "FORMAT_ERR " <> inspect(e) end
  ok2 = case Code.string_to_quoted(fmt) do {:ok, q2} -> if Macro.to_string(q2) == Macro.to_string(q), do: "same-AST", else: "AST-DIFFERS"; e -> "REPARSE_FAIL #{inspect e}" end
  IO.puts("#{String.pad_trailing(c, 48)} => #{String.pad_trailing(fmt, 40)} #{ok2}")
  IO.puts("      quoted: #{inspect(q)}")
end
IO.puts("-- Macro.to_string")
{:ok,q} = Code.string_to_quoted(~S[:Shop."New"(1)]); IO.puts Macro.to_string(q)
{:ok,q} = Code.string_to_quoted(~S[:Shop.'New'(1)]); IO.puts Macro.to_string(q)
IO.puts("-- invalid forms")
for c <- [~S[:Shop.New(1)], ~S[:Shop.New]] do IO.inspect(Code.string_to_quoted(c)) end
