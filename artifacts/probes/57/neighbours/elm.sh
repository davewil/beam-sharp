#!/usr/bin/env bash
# Elm 0.19.2: the compiler needs elm/core from package.elm-lang.org even for a one-file program.
# EXPECTED before run: `elm init` (which fetches elm/core) FAILS offline, so no Elm behaviour can be measured.
# Nothing about Elm's treatment of `x >= -5` or negative literal patterns is claimed in the brief.
E=/tmp/claude-0/tools/node_modules/.bin/elm
D=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}/elm
mkdir -p "$D"; cd "$D"
echo "elm $($E --version)"
out=$(echo y | timeout 90 $E init 2>&1)
printf '%s\n' "$out" | grep -m2 -E 'ProxyConnectException|Forbidden|PROBLEM'
if [ -f elm.json ]; then echo "FAIL elm init succeeded (prediction wrong; Elm probes could be run)"; else echo "PASS elm init failed as predicted -> Elm NOT measured"; fi
