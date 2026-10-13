#!/usr/bin/env bash
# Ticket 62 P1: every Elixir spelling of a call to a PascalCase B# export, run for real.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); C=$HERE/../../../compiler
BSC=${BSC:-$C/_build/default/bin/bsc}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir "$W/ebin"
"$BSC" --src-root "$C/examples" -o "$W/ebin" "$C/examples/Shop" >/dev/null 2>&1
cat > "$W/t.exs" <<'X'
Code.prepend_path(System.get_env("EB"))
spellings = [
  ~S|:Shop.New(1)|,
  ~S|:Shop."New"(1)|,
  ~S|:"Shop"."New"(1)|,
  ~S|apply(:Shop, :New, [1])|,
  ~S|(&:Shop."New"/1).(1)|,
  ~S|Kernel.apply(:Shop, :New, [1])|,
  ~S|mod = :Shop; mod."New"(1)|,
  ~S|:erlang.apply(:Shop, :New, [1])|,
  ~S|:Shop.new(1)|
]
for s <- spellings do
  r = try do
    {v, _} = Code.eval_string(s); {:ok, v}
  rescue e -> {:error, e.__struct__}
  catch k, v -> {k, v} end
  IO.puts(String.pad_trailing(s, 40) <> inspect(r))
end
X
EB="$W/ebin" elixir "$W/t.exs" 2>&1 | grep -v "^warning"

echo "=== P2: Gleam — does it downcase FUNCTION names? (it does not: a PascalCase fn is a syntax error; only constructor TAGS are snake-cased)"
if command -v gleam >/dev/null; then
  mkdir -p "$W/gl/src"; printf 'name = "g62"\nversion = "1.0.0"\n' > "$W/gl/gleam.toml"
  printf 'pub type Shape { MyCircle(radius: Int) HTTPServer }\npub fn make() -> Shape { MyCircle(3) }\npub fn srv() -> Shape { HTTPServer }\n' > "$W/gl/src/g62.gleam"
  (cd "$W/gl" && gleam build >/dev/null 2>&1)
  erl -noshell -pa "$W/gl/build/dev/erlang/g62/ebin" -eval 'io:format("constructor tags: ~p ~p~n",[g62:make(), g62:srv()]),halt().'
  printf 'pub fn Make() -> Int { 1 }\n' > "$W/gl/src/bad.gleam"; (cd "$W/gl" && gleam build 2>&1 | grep -m1 "error")
fi
echo "=== P3: acronym-aware derivation over the corpus (collisions / oddities)"
elixir "$HERE/derive.exs" "$HERE/../../../compiler/examples" 2>&1 | grep -v "^warning"
echo "=== P4: BEAM cost of in-module snake_case aliases (Shop)"
mkdir -p "$W/o"; "$BSC" --src-root "$HERE/../../../compiler/examples" -o "$W/o" "$HERE/../../../compiler/examples/Shop" >/dev/null 2>&1
mkdir -p "$W/o2"; OUT="$W/o2" escript "$HERE/alias_cost.escript" "$W/o/Shop.abstr"
echo "=== P5: generated Elixir-facing facade module 'Elixir.Shop'"
OUT="$W/o" escript "$HERE/facade.escript" "$W/o/Shop.abstr"
EB="$W/o" elixir -e 'Code.prepend_path(System.get_env("EB")); IO.inspect({Shop.new(7), Shop.total(4)}, label: "plain Elixir via facade")' 2>&1 | grep -v warning
