#!/bin/bash
# Attempt: compile a scratch Elm file with negative-literal patterns and constant arithmetic.
# Result recorded in 08_elm.out: `elm make` could not run - it fetches https://package.elm-lang.org/all-packages and the
# egress proxy answers 403 (policy denial; not retried, not worked around). Elm is therefore NOT surveyed by execution.
cd "$(dirname "$0")/elm_attempt"
echo "elm $(/tmp/claude-0/dl/elmi/node_modules/.bin/elm --version)"
ELM_HOME=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57/elm/.elmhome \
  timeout 120 /tmp/claude-0/dl/elmi/node_modules/.bin/elm make src/Main.elm --output=/dev/null 2>&1 | head -14
