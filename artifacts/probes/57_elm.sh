#!/usr/bin/env bash
# 57_elm -- survey: negative literals in Elm patterns, expressions, comparisons.
# Claims: (1) `-5` is accepted as a pattern (`case x of -5 -> ..`) and as an expression;
# (2) `x >= -5` and `x >= 2 + 3` are accepted (Elm has no guards, `if` takes any Bool expression);
# (3) `2 + 3` and `-(-5)` are refused as patterns; (4) Elm has no refinement types and does not check
# integer exhaustiveness (a case on Int needs `_`).
# REFUTED by: (1) refused, or `2 + 3` accepted as a pattern, or `case x of -5 -> .. ; _ -> ..` rejected.
# SETUP LIMIT: package.elm-lang.org is blocked; elm/core 1.0.5 and elm/json 1.1.3 are `git clone`d from github and the registry is
# hand-written (60_elm_registry.py). Elm's behaviour on the resolved package is real. No Elm compiler source is
# installed (Haskell binary): this survey is by running programs only.
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
S=$(mktemp -d /tmp/probe57elm.XXXXXX); export ELM_HOME=$S/home; P=$ELM_HOME/0.19.2/packages
mkdir -p $P/elm
git -c advice.detachedHead=false clone -q --depth 1 --branch 1.0.5 https://github.com/elm/core $P/elm/core/1.0.5 || exit 1
git -c advice.detachedHead=false clone -q --depth 1 --branch 1.1.3 https://github.com/elm/json $P/elm/json/1.1.3 || exit 1
rm -rf $P/elm/*/*/.git
python3 "$D/60_elm_registry.py" $ELM_HOME elm/core@1.0.5 elm/json@1.1.3
elm --version
try () { # label, module-body
  local d=$S/$RANDOM; mkdir -p $d/src
  cat > $d/elm.json <<'T'
{"type":"application","source-directories":["src"],"elm-version":"0.19.2",
 "dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},
 "test-dependencies":{"direct":{},"indirect":{}}}
T
  { echo 'module Main exposing (..)'; echo "$2"; } > $d/src/Main.elm
  out=$(cd $d && elm make src/Main.elm --output=/dev/null 2>&1); rc=$?
  if [ $rc = 0 ]; then printf '%-38s accepted\n' "$1"
  else printf '%-38s REFUSED\n%s\n' "$1" "$(echo "$out" | grep -v '^$' | head -${3:-7} | sed 's/^/      /')"; fi
}
try "expr  v = -5"                  $'v : Int\nv = -5'
try "expr  v = -(-5)"               $'v : Int\nv = -(-5)'
try "expr  v = 5 - -5" $'v : Int\nv = 5 - -5'
try "expr  v = 2 * -3"              $'v : Int\nv = 2 * -3'
try "compare  f x = x >= -5"        $'f : Int -> Bool\nf x = x >= -5'
try "compare  f x = x >= 2 + 3"     $'f : Int -> Bool\nf x = x >= 2 + 3'
try "pattern  -5"                   $'f : Int -> String\nf x =\n    case x of\n        -5 -> "m5"\n        _ -> "other"'
try "pattern  -(-5) (MUST refuse)"  $'f : Int -> String\nf x =\n    case x of\n        -(-5) -> "p5"\n        _ -> "other"'
try "pattern  2 + 3 (MUST refuse)"  $'f : Int -> String\nf x =\n    case x of\n        2 + 3 -> "five"\n        _ -> "other"'
try "pattern  5 + catch-all (control)" $'f : Int -> String\nf x =\n    case x of\n        5 -> "p5"\n        _ -> "other"'
try "no catch-all, no negative (MUST ref)" $'f : Int -> String\nf x =\n    case x of\n        5 -> "p5"\n        0 -> "z"'
try "pattern  -5.0 float (MUST refuse)" $'f : Float -> String\nf x =\n    case x of\n        -5.0 -> "m"\n        _ -> "o"'
try "case with if-guard-free  n>=-5"  $'f : Int -> String\nf x =\n    if x >= -5 then "ge" else "lt"'
