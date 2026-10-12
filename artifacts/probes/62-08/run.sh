#!/usr/bin/env bash
# Probe 62-08: Elm (compiles to JS, not BEAM) -- can it even be run here? Tries a PascalCase function name.
W=$(mktemp -d); cd $W; mkdir src
printf 'module Main exposing (..)\n\nNew x = x + 1\n' > src/Main.elm
echo '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -20
rm -rf $W
