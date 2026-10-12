#!/usr/bin/env bash
# Probe 64/10 - Elm. SOURCE-CITED, NOT RUN: `elm make` needs package.elm-lang.org's registry, which the proxy
# refuses (403), so the type behaviour of Elm is KNOWLEDGE + the cited elm/core source, not an executed compile.
# This script (a) clones elm/core 1.0.5 from github and cites Dict.get / Maybe, (b) attempts `elm make` with the
# package pre-seeded in a private ELM_HOME and records the failure honestly.
set -u
W=$(mktemp -d); trap 'rm -rf $W' EXIT
export ELM_HOME=$W/elmhome
mkdir -p $ELM_HOME/0.19.1/packages/elm/core $ELM_HOME/0.19.1/packages/elm/json $W/p/src
git clone -q -c advice.detachedHead=false --depth 1 --branch 1.0.5 https://github.com/elm/core.git $ELM_HOME/0.19.1/packages/elm/core/1.0.5
git clone -q -c advice.detachedHead=false --depth 1 --branch 1.1.3 https://github.com/elm/json.git $ELM_HOME/0.19.1/packages/elm/json/1.1.3
C=$ELM_HOME/0.19.1/packages/elm/core/1.0.5/src
echo "elm: $(elm --version)"
echo "--- elm/core 1.0.5 source"
grep -n "^get : comparable -> Dict comparable v -> Maybe v" $C/Dict.elm
grep -n "^type Maybe a" $C/Maybe.elm; sed -n 39,42p $C/Maybe.elm | sed 's/^/    /'
grep -n "^type Result error value" $C/Result.elm
cat > $W/p/elm.json <<'J'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": { "elm/core": "1.0.5", "elm/json": "1.1.3" }, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
J
cat > $W/p/src/Main.elm <<'E'
module Main exposing (..)
import Dict exposing (Dict)
d : Dict String (Maybe Int)
d = Dict.fromList [("a", Nothing)]
present : Maybe (Maybe Int)
present = Dict.get "a" d
E
echo "--- elm make attempt"
( cd $W/p && timeout 120 elm make src/Main.elm --output=/dev/null 2>&1 | grep -v "^$" | head -8 )
