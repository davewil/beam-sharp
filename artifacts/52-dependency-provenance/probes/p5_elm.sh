#!/bin/sh
# PROBE 5 — Elm 0.19.1: does elm init / elm make work offline, and what does the resulting elm.json record?
# PREDICTION: `elm init` needs the package registry/elm/core over the network; in this sandbox it will fail or hang -> report and STOP.
# (If it does succeed, elm.json is read: direct+indirect deps pinned to EXACT versions, no ranges for applications.)
cd "$(dirname "$0")"; W=work/p5; rm -rf $W; mkdir -p $W; cd $W
elm --version
export ELM_HOME=$PWD/elmhome
echo "== elm init (timeout 60s, answers y)"; yes | timeout 60 elm init; echo "exit=$?"
ls; test -f elm.json && cat elm.json
