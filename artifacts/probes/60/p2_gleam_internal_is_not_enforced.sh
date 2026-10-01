#!/usr/bin/env bash
# Ticket 60: Gleam's `internal_modules` -- is it a compile-time who-may-name-this check, or something weaker?
# Control design: the SAME module path (`lib/hidden`, which is NOT a conventional "internal" name) is built twice,
# once listed in internal_modules and once not, and we compare (1) whether a consumer package compiles
# and (2) what `gleam export package-interface` reports.
export PATH=/tmp/tools:$PATH
run() { # label, internal_modules line (may be empty)
  W=$(mktemp -d); cd "$W"; mkdir -p lib/src/lib app/src
  printf 'name = "lib"\nversion = "1.0.0"\ntarget = "erlang"\n%s\n' "$2" > lib/gleam.toml
  printf 'pub fn helper() -> Int { 42 }\n' > lib/src/lib/hidden.gleam
  printf 'pub fn api() -> Int { 1 }\n' > lib/src/lib.gleam
  printf 'name = "app"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\nlib = { path = "../lib" }\n' > app/gleam.toml
  printf 'import lib/hidden\npub fn main() { hidden.helper() }\n' > app/src/app.gleam
  echo "### $1"
  (cd app && gleam build >out.txt 2>&1; echo "consumer importing lib/hidden: gleam build exit=$?"; grep -i -E 'error|warning|internal' out.txt)
  (cd lib && gleam export package-interface --out i.json >/dev/null 2>&1; python3 -c "import json;print('package-interface modules:',sorted(json.load(open('i.json'))['modules']))")
}
run "lib/hidden NOT listed"            ''
run "lib/hidden listed as internal"    'internal_modules = ["lib/hidden"]'
