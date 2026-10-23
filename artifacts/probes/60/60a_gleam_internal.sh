#!/usr/bin/env bash
# PROBE 60a — does Gleam ENFORCE "who may name this"? (@internal attribute, internal_modules)
# Claim under test: Gleam's internal marking is advisory across packages (hidden from docs/suggestions,
# still compiles, still callable from Erlang). Control: a *private* (non-pub) function IS refused.
# Needs: source env.sh first. No hex access: packages use zero dependencies.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/lib/src/lib/internal" "$W/app/src"
cat > "$W/lib/gleam.toml" <<T
name = "lib"
version = "1.0.0"
T
cat > "$W/lib/src/lib.gleam" <<'G'
import lib/internal/secret

pub fn api() -> Int { secret.helper() + 1 }

@internal
pub fn attr_internal() -> Int { 7 }

fn really_private() -> Int { 9 }
G
cat > "$W/lib/src/lib/internal/secret.gleam" <<'G'
pub fn helper() -> Int { 41 }
G
cat > "$W/app/gleam.toml" <<T
name = "app"
version = "1.0.0"
[dependencies]
lib = { path = "../lib" }
T
run() { # label file-body
  printf '%s\n' "$2" > "$W/app/src/app.gleam"
  ( cd "$W/app" && rm -rf build && gleam build 2>&1 | grep -v -E 'Compiling|Compiled|Resolving|Downloading|Downloaded' | sed 's/^/      /' )
  echo "      exit=${PIPESTATUS[0]:-?} (gleam build)"
}
echo "== A. dependent PACKAGE imports lib/internal/secret (module under default internal glob lib/internal/*) =="
run A 'import lib/internal/secret
pub fn main() { secret.helper() }'
echo "== B. dependent package calls an @internal pub fn =="
run B 'import lib
pub fn main() { lib.attr_internal() }'
echo "== C. CONTROL: dependent package calls a non-pub function (must be refused) =="
run C 'import lib
pub fn main() { lib.really_private() }'
echo "== D. runtime: Erlang calls the @internal fn and the internal-module fn on the built beams =="
( cd "$W/app" && printf 'import lib\npub fn main() { lib.api() }\n' > src/app.gleam && gleam build >/dev/null 2>&1
  erl -noshell -pa build/dev/erlang/*/ebin -eval '
    io:format("      lib:attr_internal() = ~p~n      lib@internal@secret:helper() = ~p~n", [lib:attr_internal(), lib@internal@secret:helper()]),
    halt().' )
echo "== E. advertised surface: does the package-interface list the internal module? =="
( cd "$W/lib" && gleam export package-interface --out "$W/pi.json" >/dev/null 2>&1; python3 -I - "$W/pi.json" <<'P'
import json,sys
d=json.load(open(sys.argv[1]))
print("      modules in package-interface:", sorted(d["modules"].keys()))
print("      lib.functions:", sorted(d["modules"]["lib"]["functions"].keys()))
P
)
