#!/usr/bin/env bash
# P8: Elm 0.19.3: a user src/List.elm beside elm/core's List. Needs elm/core from package.elm-lang.org (network).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH ELM_HOME=$S/65/elmhome
D=$S/65/p8; rm -rf $D; mkdir -p $D/src; cd $D
cat > elm.json <<'X'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
X
cat > src/List.elm <<'X'
module List exposing (map)
map : Int -> Int
map x = x
X
cat > src/Main.elm <<'X'
module Main exposing (main)
import List
main = List.map 1
X
timeout 60 $S/elm/node_modules/.bin/elm make src/Main.elm --output=/dev/null 2>&1 | head -20
echo "exit=${PIPESTATUS[0]}"
