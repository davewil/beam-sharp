#!/usr/bin/env bash
# Probe (c, Elm): try to compile an app where Main names a function Orders does not expose.
# Expected to FAIL TO RUN here: elm 0.19.0 needs elm/core from package.elm-lang.org, which the proxy blocks.
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
HERE=$(cd "$(dirname "$0")" && pwd); cd "$HERE/elm"
elm --version
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -8
echo "exit=${PIPESTATUS[0]}  (non-zero because of HTTP 403 from the proxy, NOT because of the exposing rule: nothing about Elm visibility was observed)"
