#!/usr/bin/env bash
# Probe 08 — Elm 0.19.3: try to compile an exposed + private function. Expected to FAIL here: elm/core must be downloaded from
# package.elm-lang.org, which the proxy blocks. The failure is the result; Elm claims in the brief therefore come from the repo's research file, not from this run.
H="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); cp -r "$H/elm-n/." "$W/"; cd "$W" || exit 1
export ELM_HOME="$W/elmhome"
/tmp/claude-0/elmi/node_modules/.bin/elm --version
timeout 60 /tmp/claude-0/elmi/node_modules/.bin/elm make src/Main.elm --output=/dev/null 2>&1 | head -12
