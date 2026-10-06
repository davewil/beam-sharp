#!/usr/bin/env bash
# PROBE 62-01 — Claim (ticket 62 §1): Elixir cannot call a PascalCase B# export
# with dot syntax; no module prefix helps; apply/3 works. Re-run against current
# $BSC and Elixir 1.20.4. NEW forms tested: :erlang.apply, &:Shop.New/1 capture,
# Kernel.apply, "Elixir.Shop" atom variants, macros/unquote building a remote call,
# Module.concat, and :erlang.make_fun.
# CONTROL: the lowercase form `:lists.reverse([1])` must parse and run (else the harness is broken),
# and a deliberately malformed string must report SYNTAX_ERROR (else the classifier is blind).
# Run from repo root: bash artifacts/probes/62/62_01_elixir_call_forms.sh
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/ebin"
$BSC --src-root compiler/examples -o "$W/ebin" compiler/examples/Shop >/dev/null 2>&1
$BSC --src-root compiler/examples -o "$W/ebin" compiler/examples/Shop/Reports >/dev/null 2>&1
echo "elixir: $(elixir --version | tail -1)"
cat > "$W/t.exs" <<'EXS'
Code.prepend_path(System.get_env("BS_EBIN"))
syn = fn s -> case Code.string_to_quoted(s) do {:ok,_} -> :parses; _ -> :SYNTAX_ERROR end end
show = fn l, v -> IO.puts("  " <> String.pad_trailing(l, 58) <> inspect(v)) end
run = fn l, f ->
  r = try do f.() rescue e -> {:raised, e.__struct__} catch k, v -> {k, v} end
  show.(l, r)
end
IO.puts("-- controls")
show.(":lists.reverse([1])  (parse)", syn.(":lists.reverse([1])"))
show.("malformed `:a.(` (parse)  [must be SYNTAX_ERROR]", syn.(":a.("))
IO.puts("-- parse of source forms")
for s <- [":Shop.New(1)", ~s|:"Shop".New(1)|, ~s|:"BSharp.Shop".New(1)|, ~s|:"Shop.Reports".Totals(1)|,
          ~s|:"Elixir.Shop".New(1)|, ":Shop.new(1)", "&:Shop.New/1", "&:Shop.new/1",
          ~s|&:"Shop".New/1|, "apply(:Shop, :New, [1])", "Kernel.apply(:Shop, :New, [1])",
          ":erlang.apply(:Shop, :New, [1])", "Shop.New(1)", "Shop.new(1)",
          "mod = :Shop; mod.New(1)", ~s|:Shop.unquote(:New)(1)|, ~s|:Shop."New"(1)|, ~s|:Shop.'New'(1)|] do
  show.(s, syn.(s))
end
IO.puts("-- run")
run.("apply(:Shop, :New, [1])", fn -> apply(:Shop, :New, [1]) end)
run.("Kernel.apply(:Shop, :New, [1])", fn -> Kernel.apply(:Shop, :New, [1]) end)
run.(":erlang.apply(:Shop, :New, [1])", fn -> :erlang.apply(:Shop, :New, [1]) end)
run.("Code.eval_string(\"apply(:Shop,:New,[1])\")", fn -> elem(Code.eval_string("apply(:Shop,:New,[1])"),0) end)
f = :erlang.make_fun(:Shop, :New, 1)
run.(":erlang.make_fun(:Shop,:New,1).(1)", fn -> f.(1) end)
g = Function.capture(:Shop, :New, 1)
run.("Function.capture(:Shop,:New,1).(1)", fn -> g.(1) end)
run.("[1,2] |> Enum.map(Function.capture(:Shop,:New,1))", fn -> Enum.map([1,2], g) end)
IO.puts("-- QUOTED function name (the form the ticket did not test)")
for s <- [~s|:Shop."New"(1)|, ~s|&:Shop."New"/1|, ~s|:"Shop.Reports"."Totals"(1)|] do
  show.(s, syn.(s))
end
run.(~s|eval :Shop."New"(1)|, fn -> Code.eval_string(~s|:Shop."New"(1)|) |> elem(0) end)
run.(~s|eval (&:Shop."New"/1).(2)|, fn -> Code.eval_string(~s|(&:Shop."New"/1).(2)|) |> elem(0) end)
run.("eval pipe: 3 |> :Shop.\"New\"()", fn -> Code.eval_string("3 |> :Shop.\"New\"()") |> elem(0) end)
run.(~s|CONTROL eval :Shop."Nope"(1) (must raise UndefinedFunctionError)|, fn -> Code.eval_string(~s|:Shop."Nope"(1)|) |> elem(0) end)
IO.puts("-- macros: quote/unquote with a capitalised function atom")
q = quote do: unquote(:Shop).unquote(:New)(1)
show.("quote do: unquote(:Shop).unquote(:New)(1)", Macro.to_string(q))
show.("  AST", q)
run.("  Code.eval_quoted(that)", fn -> elem(Code.eval_quoted(q),0) end)
show.("  Macro.to_string re-parses?", syn.(Macro.to_string(q)))
Code.eval_string("""
defmodule M do
  defmacro shop_new(n) do
    quote do: unquote(:Shop).unquote(:New)(unquote(n))
  end
  defmacro call(m, f, args) do
    quote do: unquote(m).unquote(f)(unquote_splicing(args))
  end
end
""")
run.("macro M.shop_new(5)", fn -> Code.eval_string("require M; M.shop_new(5)") |> elem(0) end)
run.("macro M.call(:Shop, :New, [6])", fn -> Code.eval_string("require M; M.call(:Shop, :New, [6])") |> elem(0) end)
IO.puts("-- an Elixir module that wraps it once (the idiom today)")
Code.eval_string("defmodule ShopEx do\n def new(id), do: apply(:Shop, :New, [id])\nend")
run.("ShopEx.new(3)", fn -> apply(ShopEx, :new, [3]) end)
IO.puts("-- Elixir `import :Shop` (would let callers write New(1)?)")
show.("import :Shop (parse)", syn.("import :Shop"))
r = try do Code.eval_string("import :Shop; New(1)") |> elem(0) rescue e -> {:raised, e.__struct__} catch k,v -> {k,v} end
show.("import :Shop; New(1)   (eval)", r)
r = try do Code.eval_string("import :Shop; new(1)") |> elem(0) rescue e -> {:raised, e.__struct__} catch k,v -> {k,v} end
show.("import :Shop; new(1)   (eval)", r)
EXS
BS_EBIN="$W/ebin" elixir "$W/t.exs" 2>&1 | grep -v '^\s*$'
