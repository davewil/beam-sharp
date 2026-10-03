#!/usr/bin/env bash
# elm.sh -- Elm. The installed compiler is elm 0.19.2 but it cannot compile ANYTHING here:
# package.elm-lang.org is blocked by the sandbox proxy (403), and a compile needs elm/core.
# So the real behaviour is UNMEASURED; what follows is (1) the attempt, (2) the compiler's
# Haskell source (github elm/compiler tag 0.19.1, cloned; NOT the installed 0.19.2 build).
export PATH=/opt/node22/bin:$PATH
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"; mkdir src
printf '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json
printf 'module Main exposing (f)\nf : Int -> Int\nf x = case x of\n  -5 -> 1\n  _ -> 0\n' > src/Main.elm
echo "== elm $(elm --version): attempt to compile a negative-literal pattern"
timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | grep -E "PROBLEM|ProxyConnect|statusCode" | head -3
S=${ELM_SRC:-/tmp/elmsrc/compiler/src}
if [ -d "$S" ]; then
  echo "== source: pattern numbers (Parse/Pattern.hs) -- Number.number only accepts a DIGIT first, no '-' branch"
  grep -n "Number.number E.PStart E.PNumber" -A3 "$S/Parse/Pattern.hs"
  echo "== source: the diagnostic for '-' in a pattern (Reporting/Error/Syntax.hs)"
  grep -n "pattern match on negative numbers" -B1 -A1 "$S/Reporting/Error/Syntax.hs"
  echo "== source: expressions get a Negate node (Parse/Expression.hs possiblyNegativeTerm) and it is never folded in the parser"
  grep -n "possiblyNegativeTerm ::" -A6 "$S/Parse/Expression.hs"
else echo "(elm source not cloned: UNMEASURED)"; fi
