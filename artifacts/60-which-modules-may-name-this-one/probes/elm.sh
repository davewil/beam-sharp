#!/usr/bin/env bash
# P3: Elm exposed-modules. Expected to FAIL offline (elm/core must be fetched from package.elm-lang.org).
cd "$(dirname "$0")/elm"; export HOME=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/elmhome; mkdir -p $HOME
timeout 60 /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/elm/node_modules/.bin/elm make src/Reports.elm --output=/dev/null 2>&1 | head -15; echo "exit=${PIPESTATUS[0]}"
