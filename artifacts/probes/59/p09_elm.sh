#!/usr/bin/env bash
# p09 -- Elm 0.19.0: try to compile.  EXPECTED TO FAIL HERE: the compiler needs elm/core from
# package.elm-lang.org and the sandbox proxy returns 403.  The probe records that, and fails (exit 1) if
# it unexpectedly SUCCEEDS, so a verifier with network learns the survey item can be upgraded.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p09"; rm -rf "$O"; mkdir -p "$O"; cp -r src/elm "$O/proj"; cd "$O/proj"
export ELM_HOME="$O/elmhome"
elm --version | tee ../version.txt
timeout 60 elm make src/Main.elm --output=/dev/null > ../elm_make.txt 2>&1; echo "exit=$?" >> ../elm_make.txt
cat ../elm_make.txt | head -20
if grep -q "HTTP PROBLEM" ../elm_make.txt; then echo "RESULT: Elm could not run here (package download blocked). Survey item is NOT first-hand."; exit 0
else echo "RESULT: elm make did something other than the expected HTTP failure -- inspect out/p09/elm_make.txt"; exit 1; fi
