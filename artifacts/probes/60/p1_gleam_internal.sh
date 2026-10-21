#!/bin/sh
# 60 / probe 1 — Gleam's answer to "who may name this module": `internal_modules` and `@internal`.
# Two packages joined by a path dependency. Measures what the consumer sees when it names (a) an internal
# MODULE, (b) an @internal FUNCTION in a public module, and (c) the same names from inside the owning package.
set -u
W=${PROBE_TMP:-$(mktemp -d)}; STD=${GLEAM_STDLIB:?set GLEAM_STDLIB}; gleam --version
mkdir -p "$W/lib/src/lib/internal" "$W/app/src"
cat > "$W/lib/gleam.toml" <<T
name = "lib"
version = "1.0.0"
[dependencies]
gleam_stdlib = { path = "$STD" }
T
cat > "$W/lib/src/lib/internal/secret.gleam" <<'G'
pub fn hidden() -> Int { 1 }
G
cat > "$W/lib/src/lib.gleam" <<'G'
import lib/internal/secret

pub fn api() -> Int { secret.hidden() + helper() }

@internal
pub fn helper() -> Int { 2 }
G
cat > "$W/app/gleam.toml" <<T
name = "app"
version = "1.0.0"
[dependencies]
gleam_stdlib = { path = "$STD" }
lib = { path = "$W/lib" }
T
echo '== (c) owning package builds with its own internal import'
(cd "$W/lib" && gleam build 2>&1 | tail -2)
echo '== (a) consumer names an internal module'
cat > "$W/app/src/app.gleam" <<'G'
import lib/internal/secret

pub fn main() { secret.hidden() }
G
(cd "$W/app" && gleam build 2>&1 | grep -v '^$' | head -14; echo "exit=$?")
echo '== (b) consumer calls an @internal function of a public module'
cat > "$W/app/src/app.gleam" <<'G'
import lib

pub fn main() { lib.helper() }
G
(cd "$W/app" && gleam build 2>&1 | grep -v '^$' | head -14)
