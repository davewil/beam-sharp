#!/usr/bin/env bash
# CLAIM (mine): I can NOT observe Elm's dependency provenance here: `elm make` needs package.elm-lang.org even to
# read elm.json's `dependencies`, and the sandbox blocks it. This probe exists so that the gap is a recorded
# result, not an omission.
# REFUTED IF: `elm make` succeeds offline (then the Elm survey below should be re-run with real output).
. "$(dirname "$0")/lib.sh"
E=$WORK/elm; rm -rf "$E"; mkdir -p "$E"; cp -r "$ROOT/fixtures/elm/." "$E"; cd "$E"
elm --version
HOME=$WORK/elmhome timeout 90 elm make src/Main.elm --output="$E/out.js" 2>&1 | head -16; echo "[exit=${PIPESTATUS[0]}]"
