#!/usr/bin/env bash
# 57-07 Gleam and Elm: negative literals in patterns/guards, constant arithmetic in the same sites.
# EVIDENCE IS EXECUTED RUNS ONLY; neither compiler's source is installed.
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT; cd "$work"
gleam --version; elm --version
echo "== Gleam =="
gleam new g --skip-git --skip-github >/dev/null 2>&1; cd g
# hex.pm is unreachable: drop every dependency (and the test dir that needs gleeunit).
printf 'name = "g"\nversion = "1.0.0"\n' > gleam.toml; rm -rf test
try () { # $1=label  stdin=module body
  cat > src/g.gleam; out=$(gleam build 2>&1); if echo "$out" | grep -q "^error"; then echo "$1: REFUSED"; echo "$out" | grep -A6 '^error' | head -9 | sed 's/^/    /'; else echo "$1: accepted"; fi; }
try "pattern -1"            <<'EOS'
pub fn f(x: Int) -> Int { case x { -1 -> 1 _ -> 0 } }
EOS
try "guard x >= -5"         <<'EOS'
pub fn f(x: Int) -> Int { case x { n if n >= -5 -> 1 _ -> 0 } }
EOS
try "guard x == 2 + 3"      <<'EOS'
pub fn f(x: Int) -> Int { case x { n if n == 2 + 3 -> 1 _ -> 0 } }
EOS
try "guard x == -n? (var)"  <<'EOS'
pub fn f(x: Int, y: Int) -> Int { case x { n if n == -y -> 1 _ -> 0 } }
EOS
try "pattern 2 + 3"         <<'EOS'
pub fn f(x: Int) -> Int { case x { 2 + 3 -> 1 _ -> 0 } }
EOS
try "const c = -5"          <<'EOS'
const c = -5
pub fn f() -> Int { c }
EOS
try "const c = 2 + 3 in guard" <<'EOS'
const c = 2 + 3
pub fn f(x: Int) -> Int { case x { n if n == c -> 1 _ -> 0 } }
EOS
echo "== Elm (0.19.2) =="
# elm needs elm/core cached AND the package registry (package.elm-lang.org, blocked here). Cloning
# elm/core and elm/json from github satisfies the cache but not the registry; the run is recorded as-is.
cd "$work"; H=$work/elmhome; mkdir -p $H/0.19.2/packages/elm/core $H/0.19.2/packages/elm/json
git clone -q -c advice.detachedHead=false --depth 1 --branch 1.0.5 https://github.com/elm/core $H/0.19.2/packages/elm/core/1.0.5
git clone -q -c advice.detachedHead=false --depth 1 --branch 1.1.3 https://github.com/elm/json $H/0.19.2/packages/elm/json/1.1.3
mkdir -p e/src && cd e; printf '{"type":"application","source-directories":["src"],"elm-version":"0.19.1","dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3"},"indirect":{}},"test-dependencies":{"direct":{},"indirect":{}}}' > elm.json
printf 'module Main exposing (..)\nf : Int -> Int\nf x = case x of\n        -1 -> 1\n        _ -> 0\n' > src/Main.elm
ELM_HOME=$H elm make src/Main.elm --output=/dev/null 2>&1 | head -12
