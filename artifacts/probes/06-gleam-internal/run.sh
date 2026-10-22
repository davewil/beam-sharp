#!/usr/bin/env bash
# Probe 06: Gleam's answer to "who may name this module": `internal_modules` (gleam.toml) and `@internal`.
# Dependency-free: two packages joined by a PATH dependency, so no Hex access is needed.
G=${GLEAM:-/tmp/claude-0/gleamx/gleam}
$G --version
T=$(mktemp -d); cd "$T"
mkdir -p shoplib/src/shoplib/internal shoplib/src/shoplib/pricing app/src
cat > shoplib/gleam.toml <<'EOS'
name = "shoplib"
version = "1.0.0"
internal_modules = ["shoplib/internal", "shoplib/internal/*"]
[dependencies]
EOS
cat > shoplib/src/shoplib/internal/recompute.gleam <<'EOS'
pub fn recompute(n: Int) -> Int { n * 3 }
EOS
cat > shoplib/src/shoplib.gleam <<'EOS'
import shoplib/internal/recompute
pub fn total(n: Int) -> Int { recompute.recompute(n) + 1 }
@internal
pub fn hidden(n: Int) -> Int { n }
EOS
cat > shoplib/src/shoplib/pricing/pricing.gleam <<'EOS'
import shoplib/internal/recompute
pub fn priced(n: Int) -> Int { recompute.recompute(n) + 100 }
EOS
cat > app/gleam.toml <<'EOS'
name = "app"
version = "1.0.0"
[dependencies]
shoplib = { path = "../shoplib" }
EOS
echo "--- 1. in-package: shoplib (incl. shoplib/pricing, a sibling subtree) imports shoplib/internal/recompute"
(cd shoplib && $G build 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}")
echo "--- 2. app imports shoplib (public API)"
cat > app/src/app.gleam <<'EOS'
import shoplib
pub fn main() { shoplib.total(1) }
EOS
(cd app && $G build 2>&1 | tail -5; echo "exit=${PIPESTATUS[0]}")
echo "--- 3. app imports shoplib/internal/recompute  (other package, internal module)"
cat > app/src/app.gleam <<'EOS'
import shoplib/internal/recompute
pub fn main() { recompute.recompute(1) }
EOS
(cd app && $G build 2>&1 | tail -12; echo "exit=${PIPESTATUS[0]}")
echo "--- 4. app calls an @internal function of a non-internal module"
cat > app/src/app.gleam <<'EOS'
import shoplib
pub fn main() { shoplib.hidden(1) }
EOS
(cd app && $G build 2>&1 | tail -12; echo "exit=${PIPESTATUS[0]}")
