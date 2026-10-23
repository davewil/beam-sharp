#!/usr/bin/env bash
# PROBE 62c — what does Gleam lower to snake_case when it emits to the BEAM? (ticket 10 §7 claim)
# Claim under test: "Gleam downcases when it emits to the BEAM: PascalCase becomes snake_case."
# Split into (A) constructors/variant tags, (B) functions, (C) a PascalCase function name written in source (control),
# (D) module names, (E) @external to a PascalCase Erlang function.
set -uo pipefail
: "${S:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
mkdir -p proj/src && cd proj
cat > gleam.toml <<'T'
name = "proj"
version = "1.0.0"
T
cat > src/proj.gleam <<'G'
pub type Shape {
  Circle(radius: Int)
  UnitSquare
  RightTriangle(a: Int, b: Int)
}
pub fn make_circle(r: Int) -> Shape { Circle(r) }
pub fn unit() -> Shape { UnitSquare }
pub fn get_id(x: Int) -> Int { x }
@external(erlang, "Shop", "New")
pub fn external_new(a: Int) -> Int
G
mkdir -p src/deep && cat > src/deep/nested_mod.gleam <<'G'
pub fn hi() -> Int { 1 }
G
echo "=== (A,B,D,E) build a legal program"
gleam build --target erlang 2>&1 | tail -3
EBIN=build/dev/erlang/proj/ebin
echo "--- beam files:"; ls $EBIN | grep beam
echo "--- exports of proj:";  erl -noshell -pa $EBIN -eval 'io:format("~p~n",[proj:module_info(exports)]),halt().'
echo "--- values (constructors become snake_case atoms/tuples):"
erl -noshell -pa $EBIN -eval 'io:format("~p ~p~n",[proj:make_circle(3), proj:unit()]),halt().'
echo "--- generated .erl for the external:"; grep -n "external_new\|'Shop'" build/dev/erlang/proj/_gleam_artefacts/proj.erl | head
echo
echo "=== (C) CONTROL: a PascalCase FUNCTION name in Gleam source"
cat > src/proj.gleam <<'G'
pub fn GetId(x: Int) -> Int { x }
G
gleam build --target erlang 2>&1 | head -14
