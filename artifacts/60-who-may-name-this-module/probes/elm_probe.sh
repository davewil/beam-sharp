#!/bin/sh
# RESULT NOTE: both builds died fetching package.elm-lang.org (proxy 403). Per task rules: stop, no Elm claims.
# PREDICTION: (needs the elm package registry; if fetch fails we stop and claim nothing.) If it builds:
#  (a) a value not in Shop.Orders' `exposing (..)` list is refused to ANY importer (what-only visibility);
#  (b) an exposed value can be imported by every module in the application, with no way to name callers.
S=${TMPDIR:-/tmp}/b60_elm; rm -rf "$S"; mkdir -p "$S/src/Shop"; cd "$S" || exit 1
cat > elm.json <<'X'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1",
 "dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
X
cat > src/Shop/Orders.elm <<'X'
module Shop.Orders exposing (total)
total : List Int -> Int
total = recompute
recompute : List Int -> Int
recompute = List.sum
X
cat > src/Main.elm <<'X'
module Main exposing (main)
import Shop.Orders
main : Int
main = Shop.Orders.total [1,2]
X
export ELM_HOME=$S/elmhome
echo "--- (b)/(baseline): exposed value used from an unrelated module"
timeout 120 elm make src/Main.elm --output=/dev/null 2>&1 | head -12
sed -i 's/Shop.Orders.total/Shop.Orders.recompute/' src/Main.elm
echo "--- (a): unexposed value used from Main"
timeout 120 elm make src/Main.elm --output=/dev/null 2>&1 | head -12
