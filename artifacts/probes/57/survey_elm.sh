#!/usr/bin/env bash
# Elm: negative literal in case patterns / guards-equivalent. elm make needs elm/core from package.elm-lang.org.
source /tmp/claude-0/env.sh
W=$(mktemp -d); cd $W; export ELM_HOME=$W/elmhome
cat > elm.json <<'EOS'
{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3","elm/browser":"1.0.2","elm/html":"1.0.0"},"indirect":{"elm/url":"1.0.0","elm/time":"1.0.0","elm/virtual-dom":"1.0.3"}},"test-dependencies":{"direct":{},"indirect":{}}}
EOS
mkdir src; cat > src/Main.elm <<'EOS'
module Main exposing (f)
f : Int -> String
f x = case x of
  -1 -> "neg1"
  0 -> "zero"
  _ -> "other"
EOS
elm --version
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | head -8
