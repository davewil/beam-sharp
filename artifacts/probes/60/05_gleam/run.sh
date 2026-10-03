#!/bin/sh
# Probe 60/05: Gleam 1.18.1 `internal_modules` (gleam.toml) and `@internal`. Two packages: lib (path dependency) and app.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"
echo "gleam $(gleam --version)"; echo; echo "lib/gleam.toml:"; sed 's/^/  /' lib/gleam.toml
try() { echo; echo "== $1"; cat > app/src/app.gleam; ( cd app && gleam build 2>&1 | grep -v '^ *Resolving\|^ *Added' ); }
try "app imports lib/internal/store: a directory NAMED internal, NOT listed in internal_modules" <<'X'
import lib/internal/store
pub fn main() -> Int { store.put(1) }
X
try "app imports lib/hidden/vault: LISTED in internal_modules = [\"lib/hidden\", \"lib/hidden/*\"]" <<'X'
import lib/hidden/vault
pub fn main() -> Int { vault.open(1) }
X
try "app calls lib.sneaky, an @internal pub fn in a public module" <<'X'
import lib
pub fn main() -> Int { lib.sneaky(1) }
X
try "app uses lib.exposes_hidden/0, which returns an @internal type" <<'X'
import lib
pub fn main() { lib.exposes_hidden() }
X
echo; echo "== docs: which functions/modules are rendered"
( cd lib && gleam docs build >/dev/null 2>&1; echo "function ids in lib.html: $(grep -o 'id="[a-z_]*"' build/dev/docs/lib/lib.html | sort -u | tr '\n' ' ')"; echo "module pages: $(cd build/dev/docs/lib && find . -name '*.html' | sort | tr '\n' ' ')" )
echo; echo "== publish (answering n at the prompt; leak check)"
( cd lib && echo n | timeout 30 gleam publish 2>&1 | tail -3 )
rm -rf lib/build app/build lib/src/*.erl
