#!/usr/bin/env bash
# Does Elixir accept :Shop.new(1) once the beam also exports a snake_case alias? (simulated by
# rewriting bsc's .abstr; the compiler itself is NOT modified.)
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/out" "$W/alias"
"$ROOT/compiler/_build/default/bin/bsc" --src-root "$ROOT/compiler/examples" -o "$W/out" "$ROOT/compiler/examples/Shop" >/dev/null 2>&1
escript "$HERE/05_alias_cost.escript" "$W/out" emit "$W/alias"
cat > "$W/t.exs" <<'X'
Code.prepend_path(System.get_env("A"))
IO.inspect(:Shop.module_info(:exports) |> Enum.sort())
IO.inspect(:Shop.new(1), label: ":Shop.new(1)")
IO.inspect(:Shop.which(:Shop.new(1)), label: ":Shop.which(:Shop.new(1))")
X
A="$W/alias" elixir "$W/t.exs" 2>&1 | grep -v "latin1"
echo "--- and PascalCase still reachable (Erlang):"
erl -noshell -pa "$W/alias" -eval "io:format(\"~p~n\",['Shop':'New'(1) =:= 'Shop':new(1)]),halt()."
