#!/usr/bin/env bash
# PROBE 62-07 — Claim: with snake_case aliases emitted (probe 62-03's transform applied to the real Shop.abstr), an
# Elixir caller gets ordinary syntax: `:Shop.new(1)`, `&:Shop.new/1`, `|>`, `import :Shop, only: [new: 1]`.
# Also: which derived names are Elixir reserved words (end, fn, do, when, not, and, or, in, nil, true, false, catch, rescue, after, else)
# and does `:Shop.end(1)` parse? CONTROL: the UNALIASED beam must still give SYNTAX_ERROR for `:Shop.New(1)` and
# UndefinedFunctionError for `:Shop.new(1)` — otherwise the aliases did nothing.
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/plain" "$W/aliased" "$W/ebin"
H=artifacts/probes/62
$BSC --src-root compiler/examples -o "$W/plain" compiler/examples/Shop >/dev/null 2>&1
erlc -o "$W/ebin" $H/alias_xform.erl
erl -noshell -pa "$W/ebin" -eval '
  {ok, F} = file:consult("'"$W"'/plain/Shop.abstr"),
  {ok, _, B} = compile:forms(alias_xform:xform(simple, wrapper, F), [debug_info, binary]),
  ok = file:write_file("'"$W"'/aliased/Shop.beam", B), halt().'
cat > "$W/t.exs" <<'EXS'
[dir] = System.argv()
Code.prepend_path(dir)
syn = fn s -> case Code.string_to_quoted(s) do {:ok,_} -> :parses; _ -> :SYNTAX_ERROR end end
ev = fn s -> try do Code.eval_string(s) |> elem(0) rescue e -> {:raised, e.__struct__} end end
show = fn l, v -> IO.puts("  " <> String.pad_trailing(l, 52) <> inspect(v)) end
IO.puts("beam dir: " <> Path.basename(dir))
show.(":Shop.New(1)  parse", syn.(":Shop.New(1)"))
show.(":Shop.new(1)  eval", ev.(":Shop.new(1)"))
show.("&:Shop.new/1 applied to 2", ev.("(&:Shop.new/1).(2)"))
show.("[1,2] |> Enum.map(&:Shop.new/1)", ev.("[1,2] |> Enum.map(&:Shop.new/1)"))
show.("3 |> :Shop.new()", ev.("3 |> :Shop.new()"))
show.("import :Shop, only: [new: 1]; new(4)", ev.("import :Shop, only: [new: 1]; new(4)"))
show.("alias-style: Shop.new(1) with `alias :Shop, as: S`", ev.("alias :Shop, as: S; S.new(1)"))
show.(":Shop.which(%{Kind: :\"Shop.Order\", Id: 1, Total: 2})", ev.(":Shop.which(%{Kind: :\"Shop.Order\", Id: 1, Total: 2})"))
IO.puts("-- Elixir reserved words as the dotted function name")
for k <- ~w(end fn do when not and or in nil true false catch rescue after else) do
  show.(":Shop.#{k}(1) parse", syn.(":Shop.#{k}(1)"))
end
EXS
echo "=== UNALIASED beam (control)"; elixir "$W/t.exs" "$W/plain" 2>&1 | grep -v '^\s*$' | head -14
echo; echo "=== ALIASED beam"; elixir "$W/t.exs" "$W/aliased" 2>&1 | grep -v '^\s*$'
