#!/bin/bash
# H1 elm: importing a module from a package not in elm.json dependencies is refused at compile time, naming the module
#    (and, if the registry is reachable, suggesting the package).
# H2 elm.json records packages WITH exact versions (so "name-only" is not Elm's choice).
# If package fetch is blocked, say so: the observation is then about the failure, not the registry.
ELM=/tmp/claude-0/dl/elmi/node_modules/.bin/elm
W=$(mktemp -d); export ELM_HOME=$W/elmhome; cd $W; mkdir -p p/src && cd p
echo "elm $($ELM --version)"
cat > elm.json <<'EOF'
{ "type":"application","source-directories":["src"],"elm-version":"0.19.1",
  "dependencies":{"direct":{},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}} }
EOF
cat > src/Main.elm <<'EOF'
module Main exposing (main)
import Html
import Json.Decode as D
main = Html.text "x"
EOF
echo "--- elm make (no packages in elm.json):"; timeout 90 $ELM make src/Main.elm --output=/dev/null 2>&1 | head -30
echo "--- elm install elm/json:"; echo y | timeout 90 $ELM install elm/json 2>&1 | head -10
echo "--- elm.json after:"; cat elm.json
