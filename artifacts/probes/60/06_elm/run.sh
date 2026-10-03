#!/bin/sh
# Probe 60/06: Elm 0.19.2 package project with "exposed-modules": ["Acme"] and a hidden Acme.Internal.Store.
# RESULT: UNMEASURED. `elm make` cannot start: it needs elm/core, which it fetches from package.elm-lang.org,
# and the session's egress policy answers 403 to that host (see /root/.ccr/README.md: not retried, not routed around).
export LC_ALL=C.UTF-8
cd "$(dirname "$0")/lib"
echo "-- with elm/core as a dependency:"; sed -i 's|"dependencies": {}|"dependencies": { "elm/core": "1.0.0 <= v < 2.0.0" }|' elm.json
timeout 60 elm make src/Acme.elm --output=/dev/null 2>&1 | head -12
echo "-- with no dependencies (does Elm compile a core-free package?):"; sed -i 's|"dependencies": { "elm/core": "1.0.0 <= v < 2.0.0" }|"dependencies": {}|' elm.json
timeout 60 elm make src/Acme.elm --output=/dev/null 2>&1 | head -6
echo "-- what the installed binary says about the field (strings only, not behaviour):"
grep -a -o 'Which modules do you want users of the package to have access to[ -~]\{0,80\}' /opt/node22/lib/node_modules/elm/bin/elm | head -1
rm -rf elm-stuff
