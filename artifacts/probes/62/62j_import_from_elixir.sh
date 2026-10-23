#!/usr/bin/env bash
# PROBE 62j — what can an Elixir caller do with `import`, with and without aliases?
# off   = the real compiler's Shop beam (PascalCase only).   deleg = prototype alias build (62d).
# Expected under the ticket's premise: import is unusable today (a capitalised name is not an Elixir identifier).
set -uo pipefail
: "${BSC:?}" "${ALIASBSC:?}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir "$W/off" "$W/deleg"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/off" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
BS_ALIAS=deleg "$ALIASBSC" --src-root "$REPO/compiler/examples" -o "$W/deleg" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
cat > "$W/t.exs" <<'X'
t = fn label, code ->
  r = try do {v, _} = Code.eval_string(code); {:ok, v} rescue e -> {:raised, e.__struct__} end
  IO.puts("  #{String.pad_trailing(label, 52)} #{inspect(r)}")
end
t.("import :Shop, only: [new: 1]; new(1)", "import :Shop, only: [new: 1]; new(1)")
t.("import :Shop, only: [\"New\": 1]; New(1)", "import :Shop, only: [\"New\": 1]; New(1)")
t.("import :Shop, only: [\"New\": 1]; \"New\"(1)", "import :Shop, only: [\"New\": 1]; \"New\"(1)")
t.("alias :Shop, as: S; S.new(1)", "alias :Shop, as: S; S.new(1)")
t.("alias :Shop, as: S; S.\"New\"(1)", "alias :Shop, as: S; S.\"New\"(1)")
t.("1 |> :Shop.new()", "1 |> :Shop.new()")
t.("Enum.map([1,2], &:Shop.new/1)", "Enum.map([1,2], &:Shop.new/1)")
X
for m in off deleg; do echo "== $m"; elixir -pa "$W/$m" "$W/t.exs" 2>&1 | grep -v 'warning:\|^$\|│\|└'; done
