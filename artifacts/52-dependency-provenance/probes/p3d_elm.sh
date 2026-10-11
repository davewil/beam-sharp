#!/usr/bin/env bash
# Probe (c), Elm 0.19.0: what does elm.json record, and what does elm do when a package is unreachable / undeclared?
# Run: ./p3d_elm.sh   (package.elm-lang.org is expected to be blocked in this sandbox)
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
W="$FX/elm"; rm -rf "$W"; mkdir -p "$W/a/src"; cd "$W/a"; export ELM_HOME="$W/elmhome"
elm --version
echo "== 1. elm init (needs the package registry for elm/core)"
yes | timeout 60 elm init 2>&1 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[1]}"
echo "== 2. hand-written elm.json with an application's dependency record"
cat > elm.json <<'J'
{
    "type": "application",
    "source-directories": ["src"],
    "elm-version": "0.19.0",
    "dependencies": {
        "direct": { "elm/core": "1.0.0" },
        "indirect": {}
    },
    "test-dependencies": { "direct": {}, "indirect": {} }
}
J
cat > src/Main.elm <<'E'
module Main exposing (main)
import Html
main = Html.text "x"
E
echo "== 3. elm make with an import (Html) whose package (elm/html) is NOT in elm.json, packages unreachable"
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[0]}"
echo "== 4. NEGATIVE CONTROL: a module with no imports (does elm.json alone get as far as the registry?)"
cat > src/Main.elm <<'E'
module Main exposing (main)
main = 1
E
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[0]}"
