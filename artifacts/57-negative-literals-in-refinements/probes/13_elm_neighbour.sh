#!/usr/bin/env bash
# Elm 0.19.2: negative literal in pattern, guard-like `if`, and arithmetic in a pattern.
# Needs the package registry only for elm/core; offline machines may fail -- output below says what happened.
d=$(mktemp -d); trap 'rm -rf $d' EXIT; cd $d
cat > elm.json <<'J'
{ "type":"application","source-directories":["src"],"elm-version":"0.19.1",
  "dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},
  "test-dependencies":{"direct":{},"indirect":{}} }
J
mkdir src
run () { printf '%s\n' "$2" > src/Main.elm; echo "== $1"; timeout 120 elm make src/Main.elm --output=/dev/null 2>&1 | head -${3:-14}; }
run "-5 in a pattern" 'module Main exposing (p)
p : Int -> String
p x =
    case x of
        -5 -> "m5"
        _ -> "o"'
run "arithmetic in a pattern" 'module Main exposing (s)
s : Int -> String
s x =
    case x of
        2 + 3 -> "five"
        _ -> "o"'
