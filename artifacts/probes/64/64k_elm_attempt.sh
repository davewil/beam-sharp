#!/usr/bin/env bash
# PROBE 64k — Elm: attempt to compile a program that stores Nothing in a Dict and looks it up.
# EXPECTED TO BE BLOCKED in this sandbox (package.elm-lang.org refuses the proxy). Recorded so the brief can say
# "Elm: source-read only" with the exact reason rather than silently omitting it. No result here is a finding about Elm.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/src" "$W/home"; cd "$W"
cat > elm.json <<'E'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}
E
cat > src/Main.elm <<'E'
module Main exposing (main)
import Dict
import Platform
main : Program () () ()
main =
    let _ = Debug.log "stored Nothing" (Dict.get "k" (Dict.fromList [("k", Nothing)]))
        _ = Debug.log "absent" (Dict.get "zzz" (Dict.fromList [("k", Nothing)]))
    in Platform.worker { init = \_ -> ((), Cmd.none), update = \_ m -> (m, Cmd.none), subscriptions = \_ -> Sub.none }
E
elm --version
HOME="$W/home" timeout 90 elm make src/Main.elm --output="$W/out.js" 2>&1 | sed -n 1,9p
[ -f "$W/out.js" ] && node -e 'global.window=global;' && echo "(compiled)" || echo "RESULT: not compiled — Elm statements in the brief are SOURCE-READ ONLY"
