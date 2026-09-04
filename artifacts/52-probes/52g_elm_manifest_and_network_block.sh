#!/usr/bin/env bash
# Probe: Elm's elm.json dependency shape, and an honest record of what could
# NOT be executed in this sandbox and why. `elm init` needs
# https://package.elm-lang.org/all-packages before it will even WRITE a file,
# and that host is denied by this sandbox's egress policy (not just a 403 from
# the destination -- the proxy itself refuses the CONNECT). So no live `elm
# init`/`elm make` transcript exists; what follows is the real captured
# refusal, plus real elm.json files fetched from raw.githubusercontent.com
# (on the allowlist) as the only honest substitute for "create a scratch
# project and inspect it".
set -euo pipefail
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "=== attempted: elm init (real command, real failure) ==="
set +e
echo Y | elm init 2>&1
echo "exit: $?"
set -e

echo
echo "=== proxy status for the denied host ==="
curl -sS "$HTTPS_PROXY/__agentproxy/status" 2>&1 | head -40 || true

echo
echo "=== substitute: a real elm/core package manifest (package-type elm.json), fetched from GitHub ==="
curl -sS --max-time 10 "https://raw.githubusercontent.com/elm/core/1.0.5/elm.json"

echo
echo "=== substitute: a real elm-todomvc APPLICATION manifest (application-type elm.json), fetched from GitHub ==="
curl -sS --max-time 10 "https://raw.githubusercontent.com/evancz/elm-todomvc/master/elm.json"
