#!/usr/bin/env bash
# Probe 6: Elm 0.19.2, offline. Can it run at all without the package registry?
# EXPECTED (stated before the run): `elm make` needs elm/core from package.elm-lang.org and there is no ~/.elm cache and no
#  network route, so it FAILS while fetching elm/core (exit 1) BEFORE reporting anything about `import Http`.
#  Therefore Elm's behaviour on an import of an uninstalled package is NOT MEASURABLE here and is recorded as 'not measured'.
# OBSERVED-DIFFERENT (first run): with elm.json listing only elm/core, elm fails EARLIER, on a local outline check
#  (MISSING DEPENDENCY elm/json), with no network involved. 6b adds elm/json to get past that outline check; expectation
#  for 6b (stated before running it): now it must reach the registry and fail on the network, exit 1, still without a word about Http.
E=${ELM:-/tmp/claude-0/tools/node_modules/.bin/elm}
here=$(cd "$(dirname "$0")" && pwd); cd "$here"
export ELM_HOME=$here/.elmhome
echo "elm version: $(timeout 20 $E --version)"
echo "=== 6a outline: elm/core only"
timeout 60 $E make src/Main.elm --output=/dev/null 2>&1 | head -8; echo "exit=${PIPESTATUS[0]}"
echo "=== 6b outline: elm/core + elm/json"
(cd b && timeout 60 $E make src/Main.elm --output=/dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}")
