#!/bin/bash
# Elm 0.19.2. `elm init` needs package.elm-lang.org, which the egress proxy denies, so NO Elm project
# with elm/core could be built here. What WAS observed is below; the dependent-package behaviour of
# `exposed-modules` is NOT reproduced.
mkdir -p /tmp/elm60z && cd /tmp/elm60z
echo "## elm init (needs the network)"; (echo y | timeout 60 elm init) 2>&1 | grep -v agent-proxy | head -4
echo "## the elm binary's own strings: which elm.json keys does it know?"
E=$(readlink -f $(which elm))
for k in exposed-modules other-modules; do printf '%s: %s occurrences\n' $k "$(strings $E | grep -c -- "$k")"; done
echo "## the elm compiler's key list around exposed-modules (one match only):"
strings $E | grep -o -E "exposed-modules[a-z-]{0,40}" | sort | uniq -c | head
