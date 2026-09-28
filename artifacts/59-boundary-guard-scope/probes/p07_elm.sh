#!/bin/sh
# p07_elm -- what Elm 0.19.1 does about an unexposed constructor (its only private/exported distinction).
# LABEL: MEASURED if elm make succeeds offline; otherwise the output says exactly what failed and NOTHING
# is claimed about Elm from this probe.
# PREDICTION: elm make needs the elm/core package from package.elm-lang.org; with the sandbox proxy it may
# fail to fetch. If it compiles: a module exposing `Order` (opaque, no constructors) refuses a forged
# `Order 5` in a second module at COMPILE time, and there is no runtime check anywhere: scope is decided
# statically and nothing is emitted per function.
cd "$(dirname "$0")" || exit 1
rm -rf work/elm && mkdir -p work/elm/src && cd work/elm || exit 1
cat > elm.json <<'J'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": { "elm/core": "1.0.5", "elm/json": "1.1.3" }, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
J
cat > src/Order.elm <<'J'
module Order exposing (Order, make, total)
type Order = Order { total : Int }
make : Int -> Order
make n = Order { total = n }
total : Order -> Int
total (Order o) = o.total
J
cat > src/Main.elm <<'J'
module Main exposing (main)
import Order
forged = Order.Order { total = 7 }
main = Order.total forged
J
export HOME="$PWD/home"; mkdir -p "$HOME"
OUT=$(timeout 120 elm make src/Main.elm --output=/dev/null 2>&1)
echo "$OUT" | head -14
case "$OUT" in
  *"PROBLEM LOADING PACKAGE LIST"*) echo "RESULT: elm make could not fetch packages (package.elm-lang.org 403 via sandbox proxy, no ~/.elm cache). No Elm claim is made from this probe." ;;
  *) echo "RESULT: see the compiler output above." ;;
esac
