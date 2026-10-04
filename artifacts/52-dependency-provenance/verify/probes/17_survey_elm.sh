#!/bin/sh
# How Elm declares provenance (Elm 0.19.2, npm binary). Network is unavailable, so only the offline
# half can be observed: what `elm init` writes, and what the compiler says about an import of a
# package that elm.json does not list. The `elm install` flow itself needs the package registry
# and is NOT reproduced here.
. "$(dirname "$0")/env.sh"
export HOME=$W/elmhome; mkdir -p $HOME
rm -rf $W/elmp && mkdir -p $W/elmp && cd $W/elmp
echo "== elm init (answers 'y'); expect it to want the network to fetch elm/core"
yes y | timeout 60 elm init 2>&1 | head -12
echo "== ls"; ls -a
echo "== elm.json, if it was written"; [ -f elm.json ] && cat -n elm.json || echo "(no elm.json)"
mkdir -p src
cat > src/Main.elm <<'E'
module Main exposing (main)
import Http
import Html
main = Html.text "x"
E
echo "== init failed offline, so write elm.json by hand in the 0.19.2 application format (this is the file elm init/install maintain)"
cat > elm.json <<'J'
{
    "type": "application",
    "source-directories": ["src"],
    "elm-version": "0.19.2",
    "dependencies": {
        "direct": { "elm/core": "1.0.5", "elm/html": "1.0.0" },
        "indirect": {}
    },
    "test-dependencies": { "direct": {}, "indirect": {} }
}
J
cat -n elm.json
echo "== elm install elm/http (the flow that edits elm.json): needs the registry"
yes y | timeout 60 elm install elm/http 2>&1 | head -8
echo "== elm make: elm.json lacks elm/json, which the compiler itself requires (a manifest check BEFORE any import is resolved)"
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -6
echo "== add elm/json to elm.json, retry: imports Http, which elm.json does not list"
sed -i 's#"elm/html": "1.0.0" }#"elm/html": "1.0.0", "elm/json": "1.1.3" }#' elm.json
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -12
echo "(exit status above is from a container with no package cache and no network: this part is INCONCLUSIVE for the import check)"
