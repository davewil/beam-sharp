#!/usr/bin/env bash
# Behavioural probe: Elm accepts a negative literal pattern but not arithmetic patterns. (elm make needs no network with no deps beyond elm/core cached.)
export PATH=$HOME/.nix-profile/bin:$PATH
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
mkdir -p src; printf '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json
t() { printf 'module M exposing (f)\n\nf : Int -> Int\nf x =\n    %s\n' "$2" > src/M.elm
  printf '%-22s ' "$1"; out=$(elm make src/M.elm --output=/dev/null 2>&1); [ $? -eq 0 ] && echo ok || echo "REFUSED: $(echo "$out" | grep -m1 -E '^-- ')"; }
t pattern_neg_lit  'case x of
        -5 -> 1
        _ -> 0'
t pattern_arith    'case x of
        2 + 3 -> 1
        _ -> 0'
t if_guard_neg     'if x >= -5 then 1 else 0'
