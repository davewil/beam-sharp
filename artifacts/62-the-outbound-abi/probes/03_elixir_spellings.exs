# Probe 03: every Elixir spelling of a call to a capitalised function. Real execution, not just parsing.
Code.prepend_path(System.get_env("BS_EBIN"))
t = fn label, src ->
  r =
    case Code.string_to_quoted(src) do
      {:error, {_, msg, tok}} -> {:PARSE_ERROR, msg <> tok}
      {:ok, ast} ->
        try do
          {v, _} = Code.eval_string(src, [], __ENV__)
          {:OK, v |> inspect() |> String.slice(0, 60)}
        rescue e -> {:RUNTIME, e.__struct__}
        catch k, v -> {:RUNTIME, {k, v}}
        end
    end
  IO.puts(String.pad_trailing(label, 44) <> inspect(r, limit: 5))
end
IO.puts("--- POSITIVE controls (lowercase function must work: control for the harness)")
t.("control :erlang.abs(-1)", ":erlang.abs(-1)")
t.("control :Shop.module_info(:module)", ":Shop.module_info(:module)")
IO.puts("--- ticket's claims")
t.(":Shop.New(1)", ":Shop.New(1)")
t.(~S|:"Shop".New(1)|, ~S|:"Shop".New(1)|)
IO.puts("--- candidate: quoted call :Shop.\"New\"(1)")
t.(~S|:Shop."New"(1)|, ~S|:Shop."New"(1)|)
t.(~S|:"Shop"."New"(1)|, ~S|:"Shop"."New"(1)|)
t.(~S|m = :Shop; m."New"(1)|, ~S|m = :Shop; m."New"(1)|)
IO.puts("--- other spellings")
t.("apply(:Shop, :New, [1])", "apply(:Shop, :New, [1])")
t.("Kernel.apply(:Shop, :New, [1])", "Kernel.apply(:Shop, :New, [1])")
t.(":erlang.apply(:Shop, :New, [1])", ":erlang.apply(:Shop, :New, [1])")
t.("Function.capture(:Shop, :New, 1).(1)", "Function.capture(:Shop, :New, 1).(1)")
t.("&:Shop.New/1", "&:Shop.New/1")
t.("(&:Shop.New/1).(1)", "(&:Shop.New/1).(1)")
t.("&:Shop.\"New\"/1", ~S|&:Shop."New"/1|)
t.("(&:Shop.\"New\"/1).(1)", ~S|(&:Shop."New"/1).(1)|)
t.("fun = &:Shop.\"New\"/1; fun.(1)", ~S|fun = &:Shop."New"/1; fun.(1)|)
t.("&Shop.New/1 (alias form)", "&Shop.New/1")
t.("&:Shop.new/1 (lowercase negative control)", "&:Shop.new/1")
t.("Module.concat unquote macro dot-call", "Module.concat([:Shop])")
t.("apply(&:Shop.\"New\"/1, [1])", ~S|apply(&:Shop."New"/1, [1])|)
t.("Kernel.apply(:Shop, :new, [1]) (neg: no such fn)", "Kernel.apply(:Shop, :new, [1])")
