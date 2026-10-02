#!/bin/bash
# Probe 60/elm: could NOT be run to its conclusion. elm 0.19.2 must fetch elm/core from
# package.elm-lang.org even for `elm make`; this sandbox's proxy answers 403.
# Intended experiment (unrun): a package with exposed-modules ["Lib"] and a hidden Lib.Internal;
# a second project depending on it importing Lib.Internal, expecting elm to refuse.
ELM=${ELM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/node_modules/.bin/elm}
cd "$(dirname "$0")"; W=$(mktemp -d); cp -r elm.json src $W; cd $W
HOME=$W timeout 90 $ELM make src/Lib.elm --output=/dev/null > out 2>&1; rc=$?
head -12 out
if grep -q "PROBLEM LOADING PACKAGE LIST" out; then echo "NOT RUN: package fetch refused; Elm claim stays unverified"; exit 0; fi
[ $rc -eq 0 ] && echo "elm make worked offline: extend this probe" && exit 2
exit 1
