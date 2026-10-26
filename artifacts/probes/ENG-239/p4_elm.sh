#!/usr/bin/env bash
# P4: does Elm 0.19.1 accept a negative literal in a case pattern and in an expression?
# Offline: elm/core must already be in ~/.elm; the first failure line is reported verbatim.
here=$(cd "$(dirname "$0")" && pwd); w=$(mktemp -d); cp -r "$here/elm/." "$w/"; cd "$w"
elm --version
elm make src/Main.elm --output=/dev/null 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}"
