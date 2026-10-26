#!/usr/bin/env bash
# Elm 0.19.1 needs elm/core from package.elm-lang.org; this host cannot reach it.
# Recorded as a failed attempt, not worked around.
set -u
d=$(mktemp -d); cd "$d"; mkdir src
printf '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3","elm/html":"1.0.0","elm/browser":"1.0.2"},"indirect":{"elm/time":"1.0.0","elm/url":"1.0.0","elm/virtual-dom":"1.0.3"}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json
printf 'module Main exposing (main)\nimport Html\nmain = Html.text "x"\n' > src/Main.elm
timeout 90 elm make src/Main.elm --output=out.js 2>&1 | head -6
