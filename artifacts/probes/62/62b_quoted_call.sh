#!/usr/bin/env bash
# PROBE 62b — can Elixir call a PascalCase B# export with ordinary call syntax if the name is quoted?
# Ticket 62's premise: "apply/3 only". Controls: unquoted form (must fail), lowercase absent name (must fail),
# alias-resolved `Shop."New"` (must fail: Shop => Elixir.Shop, a different module).
# Run: source <scratchpad>/env.sh; bash 62b_quoted_call.sh   (from anywhere)
set -uo pipefail
: "${BSC:?source env.sh first}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir "$W/ebin"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop/Reports" >/dev/null 2>&1
ls "$W/ebin" | sed 's/^/beam: /'
cat > "$W/q.exs" <<'X'
t = fn label, code ->
  r = try do
    {v, _} = Code.eval_string(code); {:ok, v}
  rescue e -> {:raised, e.__struct__}
  end
  IO.puts("#{String.pad_trailing(label, 36)} #{inspect(r)}")
end
IO.puts("--- must FAIL (controls)")
t.(":Shop.New(1)  unquoted", ":Shop.New(1)")
t.("Shop.\"New\"(1)  alias=Elixir.Shop", "Shop.\"New\"(1)")
t.(":Shop.\"Nope\"(1)  absent name", ":Shop.\"Nope\"(1)")
t.("import :Shop; \"New\"(1)", "import :Shop; \"New\"(1)")
IO.puts("--- must SUCCEED if the premise 'apply/3 only' is false")
t.(":Shop.\"New\"(1)", ":Shop.\"New\"(1)")
t.(":\"Shop.Reports\".\"Restate\"(1)  nested", ":\"Shop.Reports\".\"Restate\"(1)")
t.("1 |> :Shop.\"New\"()  pipeline", "1 |> :Shop.\"New\"()")
t.("Enum.map([1,2], &:Shop.\"New\"/1)  capture", "Enum.map([1,2], &:Shop.\"New\"/1)")
t.("apply(:Shop, :New, [1])  (baseline)", "apply(:Shop, :New, [1])")
t.("with alias: alias :Shop, as: S", "alias :Shop, as: S; S.\"New\"(1)")
X
elixir -pa "$W/ebin" "$W/q.exs" 2>&1 | grep -v 'warning\|^$'
