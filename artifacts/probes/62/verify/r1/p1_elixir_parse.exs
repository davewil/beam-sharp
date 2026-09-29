# PROBE 1 — Elixir 1.14 spellings for calling a PascalCase export `'Api':'New'/1`.
# Env: BS_EBIN = dir holding Api.beam.
#
# EXPECTED (stated before the first run):
#   :Api.New(1)                  parse=SYNTAX_ERROR   (ticket 62 §1)
#   :"BSharp.Api".New(1)         parse=SYNTAX_ERROR
#   :"Api.Reports".Totals(1), :"Elixir.Api".New(1)   SYNTAX_ERROR (the ticket's other rows)
#   :"BSharp.Api".new(1)         parses (no such module: UndefinedFunctionError)
#   :Api.new(1)                  parses, runs -> UndefinedFunctionError (no such export)
#   :Api."New"(1)                parses AND runs -> %{Kind: :"Api.Order", ...}  (quoted call name; hypothesis: this works)
#   :"Api"."New"(1)              parses and runs
#   mod.New(1)  (mod variable)   SYNTAX_ERROR or alias semantics - recorded, no prediction
#   mod."New"(1)                 parses and runs
#   :"Api".unquote(:New)(1)      parses, but unquote outside quote -> CompileError / not runnable
#   apply(:Api, :New, [1])       parses, runs
#   Kernel.apply(:Api,:New,[1])  parses, runs
#   &:Api.New/1                  SYNTAX_ERROR
#   &:Api."New"/1                parses, capture works, returns the record
#   &:Api."New"/1 then .(1)      runs
#   :Api."Get_X"(1)              runs -> 4
Code.prepend_path(System.get_env("BS_EBIN"))
parse = fn s -> case Code.string_to_quoted(s) do {:ok, _} -> "parses"; {:error, _} -> "SYNTAX_ERROR" end end
run = fn s ->
  try do
    {v, _} = Code.eval_string(s, [mod: :Api])
    "ok " <> inspect(v)
  rescue e -> "raised " <> inspect(e.__struct__)
  catch k, v -> "caught " <> inspect({k, v}) end
end
cases = [
  ":Api.New(1)", ~s|:"BSharp.Api".New(1)|, ~s|:"Api.Reports".Totals(1)|, ~s|:"Elixir.Api".New(1)|,
  ~s|:"BSharp.Api".new(1)|, ":Api.new(1)",
  ~s|:Api."New"(1)|, ~s|:"Api"."New"(1)|, ~s|mod."New"(1)|, "mod.New(1)",
  ~s|:"Api".unquote(:New)(1)|,
  "apply(:Api, :New, [1])", "Kernel.apply(:Api, :New, [1])", ":erlang.apply(:Api, :New, [1])",
  "(&:Api.New/1).(1)", ~s|(&:Api."New"/1).(1)|, ~s|(&mod."New"/1).(1)|,
  ~s|:Api."Get_X"(1)|, ~s|:Api."HTTPGet"(1)|,
  ~s|Function.capture(:Api, :New, 1).(1)|
]
for c <- cases do
  p = parse.(c)
  r = if p == "parses", do: run.(c), else: "-"
  IO.puts(c <> " | " <> p <> " | " <> r)
end
IO.puts("elixir " <> System.version() <> " otp " <> System.otp_release())
