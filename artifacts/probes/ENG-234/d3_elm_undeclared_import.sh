#!/usr/bin/env bash
# (d3) Elm, valid base (elm/core + elm/json declared). Import a module of a package NOT declared (elm/html).
set -u; D=$(mktemp -d); cd "$D"; mkdir src; export ELM_HOME=$D/elmhome
cat > elm.json <<'X'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": {"elm/core": "1.0.5", "elm/json": "1.1.3"}, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
X
echo "## control: imports only a declared package"
printf 'module Main exposing (main)\nimport Json.Decode as D\nmain = Debug.todo "x"\n' > src/Main.elm
timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}"
echo "## case: imports Html (package elm/html not declared)"
printf 'module Main exposing (main)\nimport Html\nmain = Debug.todo "x"\n' > src/Main.elm
timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -25; echo "exit=${PIPESTATUS[0]}"
