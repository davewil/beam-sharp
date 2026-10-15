#!/usr/bin/env bash
# CLAIMS: (1) Gleam's `internal_modules` (gleam.toml) / `@internal` hide items from OTHER PACKAGES only; the check
#   is compile-time; within one package nothing is refused. (2) the refusal is in the importer, not the callee.
# (header claim (1) as first written said 'refused'; the run REFUTED it -- see brief probe log.)
# REFUTED IF: app importing libpkg/internal/secret COMPILES (exit 0); or same-package import of an internal module is
#   REFUSED. CONTROL: app importing libpkg's public module compiles and runs. No hex access => no stdlib dep: both
#   packages declare [dependencies] empty (a local path dependency only).
. "$(dirname "$0")/env.sh"; S=$(mktemp -d /tmp/probe60gleam.XXXXXX); cd $S
mkdir -p libpkg/src/libpkg/internal app/src
cat > libpkg/gleam.toml <<'T'
name = "libpkg"
version = "1.0.0"
internal_modules = ["libpkg/internal", "libpkg/internal/*"]
[dependencies]
T
cat > libpkg/src/libpkg.gleam <<'T'
import libpkg/internal/secret
pub fn open() -> Int { secret.helper() + 1 }

@internal
pub fn annotated() -> Int { 7 }
T
cat > libpkg/src/libpkg/internal/secret.gleam <<'T'
pub fn helper() -> Int { 41 }
T
cat > app/gleam.toml <<'T'
name = "app"
version = "1.0.0"
[dependencies]
libpkg = { path = "../libpkg" }
T
mkdir -p ctl_app && cp -r app/. ctl_app/ 2>/dev/null
cat > app/src/app.gleam <<'T'
import libpkg
import libpkg/internal/secret
pub fn main() -> Int { libpkg.open() + secret.helper() }
T
cat > ctl_app/src/app.gleam <<'T'
import libpkg
pub fn main() -> Int { libpkg.open() }
T
sed -i 's/name = "app"/name = "ctl_app"/' ctl_app/gleam.toml; mv ctl_app/src/app.gleam ctl_app/src/ctl_app.gleam
echo "=== (1) other package imports libpkg/internal/secret (internal_modules)"; (cd app && gleam build 2>&1 | grep -v '^ *Compiling\|^ *Downloading' ; echo "exit ${PIPESTATUS[0]}")
echo "=== (1b) other package calls an @internal fn from the public module"
cat > app/src/app.gleam <<'T'
import libpkg
pub fn main() -> Int { libpkg.annotated() }
T
(cd app && gleam build 2>&1 | grep -v '^ *Compiling' ; echo "exit ${PIPESTATUS[0]}")
echo "=== CONTROL: other package uses only the public API"
(cd ctl_app && gleam build 2>&1 | tail -3; echo "exit ${PIPESTATUS[0]}"; gleam run -m ctl_app 2>&1 | tail -1)
echo "=== (3) same package: libpkg's own test-style module imports its internal module"
cat > libpkg/src/libpkg/sibling.gleam <<'T'
import libpkg/internal/secret
pub fn twice() -> Int { secret.helper() * 2 }
T
(cd libpkg && gleam build 2>&1 | tail -2; echo "exit ${PIPESTATUS[0]}")
echo "=== (4) does the BEAM stop an outsider? call the compiled internal module from Erlang"
(cd libpkg && gleam build >/dev/null 2>&1; erl -noshell -pa build/dev/erlang/libpkg/ebin -eval 'io:format("~p~n",[libpkg@internal@secret:helper()]), halt().')
echo "=== (5) generated docs (gleam docs build): public fn listed (control), internal module / @internal fn listed?"
(cd libpkg && gleam docs build >/dev/null 2>&1; D=build/dev/docs/libpkg
 echo "control  'open' in docs: $(grep -rl 'open' $D/search-data.json | wc -l) file(s)"
 echo "'secret' in docs: $(grep -rl 'secret' $D --include=*.html --include=*.json | wc -l) file(s); '@internal annotated' in docs: $(grep -rl 'annotated' $D --include=*.html --include=*.json | wc -l) file(s)")
echo "=== (6) what the gleam binary itself says about internal (strings in the binary; no source available for Gleam)"
strings -n 12 "$(readlink -f "$(which gleam)")" | grep -E 'leak internal types|internal types do not appear|internal module glob' | sort -u
