#!/usr/bin/env bash
# Probe 1: can Elixir 1.14 / OTP 25 call B# PascalCase exports? Reproduces 62a section 3(b).
# Each parse-case has a CONTROL (lowercase / known-good) that must parse, so a "SYNTAX_ERROR for everything" bug shows.
. "$(dirname "$0")/common.sh"; EB=$SCR/p1ebin; build_shop $EB
cat > $SCR/p1.exs <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
syn = fn s -> case Code.string_to_quoted(s) do {:ok,_} -> :parses; {:error, {_, m, _}} -> {:SYNTAX_ERROR, m |> to_string() |> String.split(". ") |> hd()} end end
run = fn l, f ->
  r = try do {:ok, f.()} rescue e -> {:raised, e.__struct__} catch k, v -> {k, v} end
  IO.puts(String.pad_trailing(l, 52) <> inspect(r))
end
p = fn l, v -> IO.puts(String.pad_trailing(l, 52) <> inspect(v)) end
IO.puts("-- parse (Code.string_to_quoted) --")
for s <- [~s|:Shop."New"(1)|, ~s|:Shop."New"|, ~s|:Shop."Total"(1)|, ":Shop.New(1)", ~s|:"BSharp.Shop".New(1)|, ~s|:"Elixir.Shop".New(1)|, ":Shop.new(1)", ":shop.new(1)", "Shop.New(1)", ~s|:"Shop.Reports".Totals(1)|, "mod = :Shop; mod.New(1)", ":Shop.New", ":Shop.NEW(1)", ":Shop._New(1)"] do p.(s, syn.(s)) end
IO.puts("-- run: Shop exports --")
p.("exports", :Shop.module_info(:exports) |> Enum.reject(&(elem(&1,0)==:module_info)) |> Enum.sort())
IO.puts("-- run: ways to call New/1 --")
run.("apply(:Shop, :New, [1])", fn -> apply(:Shop, :New, [1]) end)
run.("Kernel.apply(:Shop, :New, [1])", fn -> Kernel.apply(:Shop, :New, [1]) end)
run.(":erlang.apply(:Shop,:New,[1])", fn -> :erlang.apply(:Shop, :New, [1]) end)
run.("Code.eval_string quoted :Shop.\"New\"(1)", fn -> Code.eval_string(~S|:Shop."New"(1)|) |> elem(0) end)
run.("mod = :Shop; mod.\"New\"(1)   (quoted name, var module)", fn -> Code.eval_string(~S|mod = :Shop; mod."New"(1)|) |> elem(0) end)
run.("compiled defmodule C do :Shop.\"New\"(1) end", fn -> Code.compile_string(~S|defmodule C1 do def f, do: :Shop."New"(1) end|); apply(C1, :f, []) end)
run.("capture &:Shop.\"New\"/1", fn -> f = Code.eval_string(~S|&:Shop."New"/1|) |> elem(0); f.(1) end)
run.("pipe 1 |> :Shop.\"New\"()", fn -> Code.eval_string(~S[1 |> :Shop."New"()]) |> elem(0) end)
Code.compile_string("""
defmodule W do
  defmacro bs(mod, fun, args) do
    quote do: unquote(mod).unquote(fun)(unquote_splicing(args))
  end
  def via_mc(), do: Module.concat([:Shop])
end
""")
run.("macro W.bs(:Shop, :New, [1]) (mod.unquote(fun)(..))", fn -> Code.eval_string("require W; W.bs(:Shop, :New, [1])") |> elem(0) end)
run.("Module.concat([:Shop]) === :Shop ?", fn -> apply(W, :via_mc, []) === :Shop end)
run.("Module.concat([:Shop]).New(1)", fn -> Code.eval_string(~S|Module.concat([:Shop]).New(1)|) |> elem(0) end)
run.("Module.safe_concat([\"Shop\"])", fn -> Module.safe_concat(["Shop"]) end)
run.("`import :Shop` then New(1)", fn -> Code.eval_string("import :Shop\nNew(1)") |> elem(0) end)
run.("`import :Shop` then new(1)  (control: absent)", fn -> Code.eval_string("import :Shop\nnew(1)") |> elem(0) end)
run.("control: :lists.reverse([1,2])", fn -> :lists.reverse([1,2]) end)
EXEOF
BS_EBIN=$EB elixir $SCR/p1.exs 2>&1 | grep -v '^warning\|^  (elixir\|p1.exs:\|^$'
