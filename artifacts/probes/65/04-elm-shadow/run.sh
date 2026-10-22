#!/usr/bin/env bash
# Probe 65/04: Elm 0.19.3 -- can a project define a module named like a default import (List, Maybe)?
# Elm needs elm/core from package.elm-lang.org to compile ANYTHING; that host is blocked in the
# probe environment, so this probe is expected to be UNABLE to answer. It records the failure
# rather than a claim. Re-run on a machine with network to get the real answer.
set -u
ELM="${ELM:-/tmp/claude-0/elmi/node_modules/.bin/elm}"
"$ELM" --version
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export ELM_HOME="$T/elmhome"
mkdir -p "$T/p/src"
cat > "$T/p/elm.json" <<'EOS'
{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",
  "dependencies": { "direct": { "elm/core": "1.0.5", "elm/json": "1.1.3" }, "indirect": {} },
  "test-dependencies": { "direct": {}, "indirect": {} } }
EOS
cat > "$T/p/src/List.elm" <<'EOS'
module List exposing (mine)
mine : Int
mine = 1
EOS
cat > "$T/p/src/Main.elm" <<'EOS'
module Main exposing (main)
import List

main = Platform.worker { init = \_ -> ((), Cmd.none), update = \_ m -> (m, Cmd.none), subscriptions = \_ -> Sub.none }
x = String.fromInt List.mine
EOS
echo "=== elm make with a user module named List (needs elm/core)"
(cd "$T/p" && timeout 90 "$ELM" make src/Main.elm --output=/dev/null 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}")
