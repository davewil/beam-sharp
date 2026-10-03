#!/bin/sh
# p08/elm: where Elm says what a program needs, and what a missing package does. (npm elm 0.19.2)
# LIMIT: package.elm-lang.org is blocked by the sandbox egress proxy and ~/.elm has no cached packages, so
# nothing that needs elm/core can compile here. What is measured is the elm.json-level behaviour only.
export PATH=/opt/node22/bin:$PATH ELM_HOME=$(mktemp -d)
T=$(mktemp -d); cd $T; mkdir src
printf 'module Main exposing (main)\nimport Html\nmain = Html.text "hi"\n' > src/Main.elm
echo "## 1. source file: the import names a MODULE only"; cat src/Main.elm
echo "## 2. elm.json with no elm/core"
cat > elm.json <<'X'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": {}, "indirect": {} }, "test-dependencies": { "direct": {}, "indirect": {} } }
X
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -8
echo "## 3. elm.json declaring elm/core + elm/html (the package manifest) but packages not installed and registry unreachable"
cat > elm.json <<'X'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": {"elm/core": "1.0.5", "elm/html": "1.0.0"}, "indirect": {"elm/json":"1.1.3","elm/virtual-dom":"1.0.3","elm/browser":"1.0.2","elm/time":"1.0.0","elm/url":"1.0.0"} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
X
timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -14
