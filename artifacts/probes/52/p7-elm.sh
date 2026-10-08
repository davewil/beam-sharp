#!/usr/bin/env bash
# P7: Elm 0.19.3 (npm), one attempt each. Expected on this box: registry/package downloads blocked.
# Evidence is the failure itself; nothing about elm.json semantics is claimed from this probe.
S=$(mktemp -d); cd "$S"
ELM=/tmp/elmi/node_modules/.bin/elm
echo "--- elm --version"; timeout 30 $ELM --version
echo "--- elm init (Y)"; yes | HOME=$S/h timeout 60 $ELM init 2>&1 | sed -n '10,16p'
echo "--- hand-written elm.json with elm/core only, a source that imports an UNLISTED package module (Json.Decode)"
mkdir src; cat > elm.json <<'J'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1",
 "dependencies":{"direct":{"elm/core":"1.0.5"},"indirect":{}},
 "test-dependencies":{"direct":{},"indirect":{}}}
J
printf 'module Main exposing (x)\nimport Json.Decode\nx = 1\n' > src/Main.elm
HOME=$S/h timeout 60 $ELM make src/Main.elm --output=/dev/null 2>&1 | head -12
