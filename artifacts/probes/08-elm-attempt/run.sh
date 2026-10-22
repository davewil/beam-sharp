#!/usr/bin/env bash
# Probe 08: Elm 0.19.3.  A *package* hides modules not listed in elm.json "exposed-modules"; an
# application has no such list.  Verifying needs elm/core from package.elm-lang.org, which the
# sandbox proxy blocks, so this probe records the failure instead of a result.
ELM=${ELM:-/tmp/claude-0/elmi/node_modules/.bin/elm}
$ELM --version
T=$(mktemp -d); cd "$T"; mkdir -p src
cat > elm.json <<'EOS'
{"type":"package","name":"me/shop","summary":"s","license":"MIT","version":"1.0.0",
 "exposed-modules":["Orders"],"elm-version":"0.19.0 <= v < 0.20.0","dependencies":{"elm/core":"1.0.0 <= v < 2.0.0"},"test-dependencies":{}}
EOS
echo 'module Orders exposing (total)
import Orders.Internal
total n = Orders.Internal.recompute n + 1' > src/Orders.elm
mkdir -p src/Orders; echo 'module Orders.Internal exposing (recompute)
recompute n = n * 3' > src/Orders/Internal.elm
ELM_HOME=$T/home timeout 60 $ELM make src/Orders.elm --output=/dev/null 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}"
