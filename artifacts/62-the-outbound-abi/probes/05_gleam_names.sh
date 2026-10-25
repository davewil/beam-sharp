#!/usr/bin/env bash
# Probe 05: what does gleam 1.19.1 actually emit for PascalCase type/constructor names, function names,
# module names? Does it "downcase PascalCase function names"? (ticket 10 s7 claim: "PascalCase to snake_case")
# Usage: 05_gleam_names.sh <scratch-dir>   (needs gleam, erl on PATH; no hex deps required)
set -u
G=${1:?scratch dir}; rm -rf "$G"; mkdir -p "$G/src/deep"
cat > "$G/gleam.toml" <<'T'
name = "caller"
version = "1.0.0"
[dependencies]
T
cat > "$G/src/caller.gleam" <<'T'
pub type Shape { Circle(radius: Int) UnitSquare HTTPError(code: Int) }
pub type IOError { ReadFailed }
pub fn to_json(s: Shape) -> Int { case s { Circle(r) -> r  _ -> 0 } }
pub fn make() -> List(Shape) { [Circle(1), UnitSquare, HTTPError(3)] }
pub fn read() -> IOError { ReadFailed }
T
cat > "$G/src/deep/nested.gleam" <<'T'
pub type T { SomeTag(Int) }
pub fn go() -> T { SomeTag(1) }
T
echo "=== NEGATIVE: can a Gleam FUNCTION be PascalCase?"
cat > "$G/src/caller2.gleam" <<'T'
pub fn ToJson(x: Int) -> Int { x }
T
(cd "$G" && gleam build 2>&1 | head -20)
rm "$G/src/caller2.gleam"
echo "=== NEGATIVE: can a Gleam MODULE FILE be PascalCase?"
echo 'pub fn x() { 1 }' > "$G/src/Bad.gleam"
(cd "$G" && gleam build 2>&1 | head -12)
rm "$G/src/Bad.gleam"
echo "=== positive build"
(cd "$G" && gleam build 2>&1 | tail -2)
echo "=== module atoms"; ls "$G/build/dev/erlang/caller/ebin"
echo "=== exports of caller.beam"
erl -noshell -pa "$G/build/dev/erlang/caller/ebin" -eval 'io:format("~p~n",[caller:module_info(exports)]), io:format("make() = ~p~n",[caller:make()]), io:format("read() = ~p~n",[caller:read()]), io:format("deep@nested:go() = ~p~n",['"'"'deep@nested'"'"':go()]), halt().'
echo "=== generated .erl (gleam export erlang-shipment / --target erlang keeps .erl?)"
find "$G/build" -name '*.erl'
