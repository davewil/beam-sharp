#!/usr/bin/env bash
# PROBE 62_gleam_case (ticket 62)
# CLAIM under test (ticket 62 option 2 / ticket 10 s.7): "Gleam downcases when it
# emits to the BEAM -- PascalCase becomes snake_case", offered as precedent for
# emitting snake_case ALIASES of PascalCase function names.
# Method: compile Gleam with (a) functions, (b) constructors of a custom type,
# (c) types, (d) module names, each written in every case we can get past the
# front end; print what lands in the .beam (exports, atoms in the code).
# REFUTES the ticket's reading of the precedent if (i) Gleam REJECTS a PascalCase
# function / module name instead of downcasing it, and (ii) the only thing that
# lands snake_case is constructors (data atoms), never an exported function.
# Also: @external(erlang, "Shop", "New") compiles AND RUNS (ticket only compiled).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/ebin"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null || exit 2
P="$W/proj"; mkdir -p "$P/src"
cat > "$P/gleam.toml" <<'T'
name = "probe"
version = "1.0.0"
target = "erlang"
T
try() { # label, file-body, module name
  printf '%s' "$2" > "$P/src/$3.gleam"
  echo "### $1  (src/$3.gleam)"
  (cd "$P" && gleam build 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^$" | head -${4:-12})
  rm -f "$P/src/$3.gleam"
}
echo "=== 1. function names (control: snake_case compiles) ==="
try "snake_case fn"  $'pub fn new_order(x: Int) -> Int { x }\n' good
try "PascalCase fn"  $'pub fn NewOrder(x: Int) -> Int { x }\n' bad_fn
try "camelCase fn"   $'pub fn newOrder(x: Int) -> Int { x }\n' bad_fn2
echo "=== 2. module (file) names ==="
try "PascalCase module file" $'pub fn f() { 1 }\n' Shop
try "camelCase module file"  $'pub fn f() { 1 }\n' shopThing
try "nested snake path"      $'pub fn f() { 1 }\n' ok_name
echo "=== 3. constructors / types: what lands in the beam ==="
mkdir -p "$P/src/deep"
cat > "$P/src/deep/nested.gleam" <<'G'
pub type Shape { Circle(Int) MyHTTPThing HTTPServer(Int) X2Y GetURL2 }
pub type MyType { MyType(Int) }
pub fn make() { [Circle(1), MyHTTPThing, HTTPServer(2), X2Y, GetURL2, ] }
pub fn mk2() { MyType(3) }
G
(cd "$P" && gleam build 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^$" | head -8)
B="$P/build/dev/erlang/probe/ebin"
ls "$B"
erl -noshell -pa "$B" -eval '
  M = '"'"'deep@nested'"'"',
  io:format("exports: ~p~n", [lists:sort(M:module_info(exports))]),
  io:format("make(): ~p~n", [M:make()]),
  io:format("mk2(): ~p~n", [M:mk2()]),
  {ok,{_,[{atoms,As}]}} = beam_lib:chunks(code:which(M), [atoms]),
  io:format("atoms in beam: ~p~n", [[A || {_,A} <- As]]),
  halt().'
echo "=== 4. @external call into a B# PascalCase export: compile AND run ==="
cat > "$P/src/caller.gleam" <<'G'
@external(erlang, "Shop", "New")
fn shop_new(id: Int) -> a

pub fn main() { shop_new(7) }
G
rm -rf "$P/src/deep"
(cd "$P" && gleam build 2>&1 | grep -v "^ *Compiling\|^ *Compiled\|^$" | head -8)
erl -noshell -pa "$B" -pa "$W/ebin" -eval 'io:format("caller:main() -> ~p~n", [caller:main()]), halt().'
echo "--- imports of Gleam's caller.beam (the call it emits) ---"
erl -noshell -pa "$B" -eval '{ok,{_,[{imports,I}]}} = beam_lib:chunks(code:which(caller),[imports]), io:format("~p~n",[I]), halt().'
echo "--- does a PascalCase module file produce a beam at all? ---"
printf 'pub fn f() { 1 }\n' > "$P/src/Shop.gleam"
(cd "$P" && gleam build >/dev/null 2>&1); ls "$B" | tr '\n' ' '; echo
