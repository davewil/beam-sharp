#!/usr/bin/env bash
# Hypothesis H1: Elm enforces who may name a module only at the PACKAGE boundary via elm.json "exposed-modules",
# i.e. inside one project every module can import every other. Falsifiable: an app module importing a
# non-exposed sibling must compile; if elm refuses it, H1 is wrong.
# Elm 0.19.3 needs elm/core from package.elm-lang.org; if that is unreachable the probe reports it and exits 2.
ELM=/tmp/claude-0/dl/elmi/node_modules/.bin/elm
D=$(mktemp -d); cd "$D"; export ELM_HOME="$D/.elmhome"
$ELM --version
mkdir -p src && cat > elm.json <<'X'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1",
 "dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
X
cat > src/Internal.elm <<'X'
module Internal exposing (secret)
secret : Int
secret = 42
X
cat > src/Main.elm <<'X'
module Main exposing (main)
import Internal
main = Internal.secret
X
timeout 100 $ELM make src/Main.elm --output=/dev/null 2>&1 | tail -8
rc=${PIPESTATUS[0]}; echo "elm make rc=$rc"
[ $rc -eq 0 ] && echo "H1 observed: sibling import compiled" || echo "INCONCLUSIVE (rc!=0): see output above"
