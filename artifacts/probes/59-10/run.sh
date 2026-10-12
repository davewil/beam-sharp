#!/usr/bin/env bash
# Elm: can we execute `elm make` on a port module here? (package fetch needs package.elm-lang.org)
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); cp -r "$HERE/proj" $W/; cd $W/proj
elm --version; timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -12; echo "exit: ${PIPESTATUS[0]}"
