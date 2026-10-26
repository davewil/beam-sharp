#!/usr/bin/env bash
# (d) Elm: importing a module from a package not in elm.json. No network is available to elm's package registry check; reported as-is.
set -u; D=$(mktemp -d); cd "$D"; mkdir src; export ELM_HOME=$D/elmhome
cat > elm.json <<'X'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": {}, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
X
printf 'module Main exposing (main)\nimport Json.Decode as D\nmain = Debug.todo "x"\n' > src/Main.elm
echo "## case 1: elm.json declares nothing, source imports Json.Decode"
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}"
echo "## case 2: no import of any package module (control, same empty elm.json)"
printf 'module Main exposing (main)\nmain = 1\n' > src/Main.elm
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -8; echo "exit=${PIPESTATUS[0]}"
