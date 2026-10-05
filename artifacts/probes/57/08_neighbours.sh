#!/usr/bin/env bash
# 08 -- neighbours, run for real. Raw output kept in out/neighbours/.
# Erlang  : parse -5 / pattern / guard / expression, lint, core with and without
#           sys_core_fold (REFUTES "Erlang folds in the parser": parse showing {integer,_,-5}).
# Elixir  : string_to_quoted AST, and the erlang_v1 abstract code after expansion.
# Gleam   : build small programs, read the generated Erlang; and which spellings
#           the parser refuses (no Gleam source is installed; only tool output).
# Elm     : try; the compiler needs package.elm-lang.org, which the proxy blocks.
. "$(dirname "$0")/lib.sh"
N=$OUT/neighbours; mkdir -p "$N"
echo "== Erlang"; escript "$HERE/neighbours/erl_probe.escript" > "$N/erlang.txt" 2>&1; grep -c . "$N/erlang.txt"
grep -q "{clause,3,\[{op,3,'-',{integer,3,5}}\]" "$N/erlang.txt" && r=unfolded-in-parse || r=folded
expect "erl_parse leaves -5 as {op,'-',5} in a pattern" unfolded-in-parse $r
grep -q "LINT  {ok,\[\]}" "$N/erlang.txt" && r=ok || r=error
expect "erl_lint accepts -5 as a pattern" ok $r
echo "== Elixir"; elixir "$HERE/neighbours/elixir_ast.exs" > "$N/elixir_ast.txt" 2>&1; cat "$N/elixir_ast.txt"
elixir "$HERE/neighbours/elixir_forms.exs" > "$N/elixir_forms.txt" 2>&1; grep -E "^(f|g|h):|integer, \{[0-9]+, [0-9]+\}, -5|'-'|:-" "$N/elixir_forms.txt" | head -12
echo "== Gleam"; G=$WORK/gl; rm -rf "$G"; mkdir -p "$G/src"; printf 'name = "g57"\nversion = "1.0.0"\n[dependencies]\n' > "$G/gleam.toml"
gl () { printf '%s\n' "$2" > "$G/src/g57.gleam"; printf '%-34s ' "$1"; (cd "$G" && gleam build --target erlang 2>&1 | grep -v -E "Resolving|Compiling|Compiled in" | grep -E "error|Found|expected" | head -2 | tr '\n' ' '); [ -z "$(cd $G && gleam build --target erlang 2>&1 | grep error)" ] && echo "ACCEPTED" || echo; }
{
gl 'pattern -5'               'pub fn f(x: Int) { case x { -5 -> 1  _ -> 0 } }'
gl 'pattern - 5 (space)'      'pub fn f(x: Int) { case x { - 5 -> 1  _ -> 0 } }'
gl 'pattern -(5)'             'pub fn f(x: Int) { case x { -(5) -> 1  _ -> 0 } }'
gl 'pattern --5'              'pub fn f(x: Int) { case x { --5 -> 1  _ -> 0 } }'
gl 'pattern 2 - 3'            'pub fn f(x: Int) { case x { 2 - 3 -> 1  _ -> 0 } }'
gl 'guard n >= -5'            'pub fn f(x: Int) { case x { n if n >= -5 -> 1  _ -> 0 } }'
gl 'guard n >= - 5 (space)'   'pub fn f(x: Int) { case x { n if n >= - 5 -> 1  _ -> 0 } }'
gl 'guard n >= 2 + 3'         'pub fn f(x: Int) { case x { n if n >= 2 + 3 -> 1  _ -> 0 } }'
gl 'guard n == -m'            'pub fn f(x: Int, m: Int) { case x { n if n == -m -> 1  _ -> 0 } }'
gl 'const c = -5'             'pub const c = -5'
gl 'const c = -(5)'           'pub const c = -{5}'
gl 'const c = - -5'           'pub const c = - -5'
gl 'const c = 2 + 3'          'pub const c = 2 + 3'
gl 'expression -x'            'pub fn f(x: Int) { -x }'
gl 'expression - -5'          'pub fn f() { - -5 }'
} 2>&1 | tee "$N/gleam_acceptance.txt"
printf '%s\n' 'pub const lo = -5
pub fn f(x: Int) -> String {
  case x {
    -5 -> "neg5"
    n if n >= -5 -> "ge"
    _ -> "lt"
  }
}
pub fn h(x: Int) -> Int { x - -5 + -x }' > "$G/src/g57.gleam"; (cd "$G" && gleam build --target erlang >/dev/null 2>&1; cat build/dev/erlang/g57/_gleam_artefacts/g57.erl > "$N/gleam_generated.erl"); sed -n '/^f(X)/,$p' "$N/gleam_generated.erl"
echo "== Elm"
mkdir -p "$WORK/elm"; printf 'module Main exposing (f)\n\nf : Int -> Int\nf x =\n    case x of\n        -5 -> 1\n        _ -> 0\n' > "$WORK/elm/Main.elm"
echo '{"type":"application","source-directories":["."],"elm-version":"0.19.0","dependencies":{"direct":{},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}' > "$WORK/elm/elm.json"
(cd "$WORK/elm" && timeout 60 elm make Main.elm --output=/dev/null) > "$N/elm.txt" 2>&1; head -8 "$N/elm.txt"
