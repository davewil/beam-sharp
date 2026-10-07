#!/bin/sh
# Elm 0.19.2: a package project importing its own hidden module needs elm/core from package.elm-lang.org.
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$(dirname "$0")/lib" || exit 1
timeout 60 elm make src/Lib.elm --output=/dev/null 2>&1 | tail -6
