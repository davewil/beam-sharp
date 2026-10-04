#!/bin/bash
# Probe 11 (survey): Elm 0.19.2 is installed but package.elm-lang.org is blocked by the sandbox's
# egress proxy, so a project depending on elm/core cannot be built and NO generated JS could be
# inspected. Recorded rather than silently dropped: the Elm claims in brief.md are taken from
# wayfinder/research/18-elm-port-validation.md (which built against Elm 0.19.1 with network) and
# are marked "cited, not reproduced".
cd "$(dirname "$0")"; export PATH=/opt/node22/bin:$PATH
W=$(mktemp -d); cd $W; mkdir src
cat > elm.json <<'J'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
J
cat > src/Main.elm <<'E'
module Main exposing (main)
import Platform
type Token = Token Int
type alias Order = { id : Int, total : Int }
inner : Order -> Int
inner o = o.total
main = Platform.worker { init = \() -> ((), Cmd.none), update = \_ m -> (m, Cmd.none), subscriptions = \_ -> Sub.none }
E
elm --version
timeout 120 elm make src/Main.elm --output=out.js 2>&1 | grep -v "^$" | head -8
ls out.js 2>&1
