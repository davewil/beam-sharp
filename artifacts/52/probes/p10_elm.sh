#!/usr/bin/env bash
# p10: Elm 0.19.1 (compile-only).  Wanted: what Elm says when a source `import` names a package elm.json does not
# declare.  Elm needs elm/core from package.elm-lang.org; the proxy refuses it, so this records the failure.
cd "$(dirname "$0")/neighbours/elm_imp"
timeout 60 /tmp/tools/elm make src/Main.elm --output=/dev/null 2>&1 | head -20
echo "exit=${PIPESTATUS[0]}"
