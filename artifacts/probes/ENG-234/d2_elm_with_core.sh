#!/usr/bin/env bash
# (d2) Repeat of d with elm/core declared (d's elm.json lacked it, so d tested nothing about imports).
# Needs package.elm-lang.org; if the proxy refuses it the failure is the result.
set -u; D=$(mktemp -d); cd "$D"; mkdir src; export ELM_HOME=$D/elmhome
cat > elm.json <<'X'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": {"elm/core": "1.0.5"}, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
X
printf 'module Main exposing (main)\nimport Json.Decode as D\nmain = Debug.todo "x"\n' > src/Main.elm
timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}"
