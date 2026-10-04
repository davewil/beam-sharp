#!/bin/bash
# Gleam 1.12.0 (the tickets measured 1.18.1 -- NOT reproduced at that version). A `lib` package with
# internal_modules + @internal; an `app` package depending on it by path and importing both.
export PATH=/opt/otp28/bin:$PATH
G=/tmp/tc/gleam; W=/tmp/g60x; rm -rf $W; mkdir -p $W; cd $W
$G --version
$G new lib --skip-git --skip-github >/dev/null 2>&1; $G new app --skip-git --skip-github >/dev/null 2>&1
for p in lib app; do rm -rf $p/test; python3 - $p <<'PY'
import sys
p=sys.argv[1]+'/gleam.toml'; s=open(p).read(); open(p,'w').write(s.split('[dependencies]')[0]+'[dependencies]\n')
PY
done
python3 - <<'PY'
p='lib/gleam.toml'; s=open(p).read()
open(p,'w').write(s.replace('[dependencies]','internal_modules = ["lib/internal", "lib/internal/*"]\n\n[dependencies]'))
PY
echo 'lib = { path = "../lib" }' >> app/gleam.toml
mkdir -p lib/src/lib/internal
cat > lib/src/lib.gleam <<'G'
import lib/internal/rules
pub fn total(xs: List(Int)) -> Int { rules.recompute(xs) }
pub fn answer() -> Int { 42 }
G
cat > lib/src/lib/internal/rules.gleam <<'G'
pub fn recompute(xs: List(Int)) -> Int {
  case xs { [] -> 0  [x, ..rest] -> x + recompute(rest) }
}
G
cat > lib/src/lib/helpers.gleam <<'G'
@internal
pub fn tagged_helper() -> Int { 7 }
pub fn visible() -> Int { 1 }
G
cat > app/src/app.gleam <<'G'
import lib
import lib/helpers
import lib/internal/rules
pub fn main() {
  let _ = lib.total([1, 2, 3])
  let _ = helpers.tagged_helper()
  rules.recompute([1])
}
G
echo "## lib/gleam.toml (relevant line)"; grep internal_modules lib/gleam.toml
echo "## app imports lib/internal/rules and a @internal function from another PACKAGE:"
(cd app && $G build 2>&1; echo "exit=${PIPESTATUS[0]}")
echo "## run it"; (cd app && $G run 2>&1 | tail -2)
echo "## what internal DID change: lib's generated docs / package-interface list"
(cd lib && $G docs build >/dev/null 2>&1; python3 - <<'PY'
import json
d=json.load(open('build/dev/docs/lib/package-interface.json'))
for m,v in d['modules'].items(): print('  documented:', m, sorted(v['functions']))
PY
)
echo "## the BEAM: the internal module is an ordinary exported function (compiled artefact of the app build)"
erl -noshell -pa app/build/dev/erlang/lib/ebin -eval '{module,_}=code:ensure_loaded(lib@internal@rules), io:format("exported=~p  call=~p~n",[erlang:function_exported(lib@internal@rules, recompute, 1), lib@internal@rules:recompute([1,2,3])]), halt().'
