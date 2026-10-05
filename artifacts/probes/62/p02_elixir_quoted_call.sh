#!/usr/bin/env bash
# P02: the avenue ticket 62's table never tried -- Elixir quoted-call syntax.
# CLAIM UNDER TEST (ticket 62 §1): "Elixir cannot call a PascalCase export".
# REFUTED IF: any of the quoted forms below returns the module's result.
# CONFIRMED (claim stands) only if every non-apply spelling is a syntax error or undef.
# Each spelling is both PARSED and RUN (62a only parsed), and the result printed.
. "$(dirname "$0")/lib.sh"
OUT="$SCRATCH/p02ebin"; rm -rf "$OUT"; mkdir -p "$OUT"
"$BSC" --src-root "$REPO/compiler/examples" -o "$OUT" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
"$BSC" --src-root "$REPO/compiler/examples" -o "$OUT" "$REPO/compiler/examples/Shop/Reports" >/dev/null 2>&1
cat > "$SCRATCH/p02.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
try_it = fn label, src ->
  r =
    try do
      {v, _} = Code.eval_string(src)
      {:ok, v}
    rescue
      e -> {:raised, e.__struct__, Exception.message(e) |> String.split("\n") |> hd()}
    end
  IO.puts(String.pad_trailing(label, 44) <> inspect(r))
end
try_it.(~S':Shop."New"(1)', ~S':Shop."New"(1)')
try_it.(~S':"Shop"."New"(1)', ~S':"Shop"."New"(1)')
try_it.(~S':"Shop.Reports"."Restate"(3)', ~S':"Shop.Reports"."Restate"(3)')
try_it.(~S'mod = :Shop; mod."New"(2)', ~S'mod = :Shop; mod."New"(2)')
try_it.(~S'apply(:Shop, :New, [3])', ~S'apply(:Shop, :New, [3])')
try_it.(~S'apply(:Shop, :"New", [3])', ~S'apply(:Shop, :"New", [3])')
try_it.(~S'f = &:Shop."New"/1; f.(4)', ~S'f = &:Shop."New"/1; f.(4)')
try_it.(~S'f = &:Shop.New/1 (unquoted capture)', ~S'f = &:Shop.New/1; f.(4)')
try_it.(~S'Function.capture(:Shop, :New, 1).(5)', ~S'Function.capture(:Shop, :New, 1).(5)')
try_it.(~S':erlang.apply(:Shop, :New, [6])', ~S':erlang.apply(:Shop, :New, [6])')
try_it.(~S'Kernel.apply(:Shop,:New,[1])', ~S'Kernel.apply(:Shop, :New, [1])')
# pipe and macro forms
try_it.(~S'1 |> :Shop."New"()', ~S'1 |> :Shop."New"()')
try_it.(~S'import :Shop (all) then New(1)', ~S'import :Shop; New(1)')
try_it.(~S'import :Shop, only: [New: 1]; New(1)', ~S'import :Shop, only: [New: 1]; New(1)')
try_it.(~S'alias :Shop, as: S; S."New"(1)', ~S'alias :Shop, as: S; S."New"(1)')
try_it.(~S'import :Shop, only: [New: 1]; "New"(1)', ~S'import :Shop, only: [New: 1]; "New"(1)')
try_it.(~S'import :Shop, only: [New: 1] (import alone)', ~S'import :Shop, only: [New: 1]; :ok')
try_it.(~S':Shop.new(1)  (lowercase, no alias exports)', ~S':Shop.new(1)')
EXEOF
BS_EBIN="$OUT" elixir "$SCRATCH/p02.exs" 2>&1 | grep -v '^warning\|^  (elixir\|^  p02.exs\|^$'
