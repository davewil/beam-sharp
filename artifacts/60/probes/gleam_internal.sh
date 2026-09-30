#!/usr/bin/env bash
# Probe: what does Gleam 1.12.0 enforce for "internal"? Two packages, path dependency, no hex.
export PATH=$PATH:/tmp/tools
W=${1:-/tmp/gleam-internal-60}; rm -rf "$W"; mkdir -p "$W/lib/src/lib/internal" "$W/app/src" "$W/lib2/src/lib2/internal"
cat > "$W/lib/gleam.toml" <<T
name = "lib"
version = "1.0.0"
T
cat > "$W/lib/src/lib.gleam" <<T
import lib/internal/helper
pub fn api() -> Int { helper.round_total(41) }
@internal
pub fn sneaky() -> Int { 1 }
T
cat > "$W/lib/src/lib/internal/helper.gleam" <<T
pub fn round_total(x: Int) -> Int { x + 1 }
T
cat > "$W/app/gleam.toml" <<T
name = "app"
version = "1.0.0"
[dependencies]
lib = { path = "../lib" }
T
echo "=== A: app (other package) imports lib/internal/helper and calls lib.sneaky (@internal)"
cat > "$W/app/src/app.gleam" <<T
import lib
import lib/internal/helper
pub fn main() { let _ = lib.sneaky() let _ = helper.round_total(1) lib.api() }
T
(cd "$W/app" && gleam build 2>&1; echo "exit=$?")
echo "=== B: same package, sibling module imports lib/internal/helper (lib2 is the package; no dependency)"
cat > "$W/lib2/gleam.toml" <<T
name = "lib2"
version = "1.0.0"
T
cat > "$W/lib2/src/lib2/internal/helper.gleam" <<T
pub fn f() -> Int { 1 }
T
cat > "$W/lib2/src/lib2/other.gleam" <<T
import lib2/internal/helper
pub fn g() -> Int { helper.f() }
T
(cd "$W/lib2" && gleam build 2>&1; echo "exit=$?")
echo "=== C: internal_modules = [\"lib/internal/*\"] configured explicitly in lib"
printf 'name = "lib"\nversion = "1.0.0"\ninternal_modules = ["lib/internal/*"]\n' > "$W/lib/gleam.toml"
(cd "$W/app" && gleam build 2>&1; echo "exit=$?")
echo "=== D: what 'internal' DOES do: the exported package interface (what docs/tooling see)"
printf 'name = "lib"\nversion = "1.0.0"\n' > "$W/lib/gleam.toml"
(cd "$W/lib" && gleam export package-interface --out "$W/pi.json" >/dev/null 2>&1; python3 - "$W/pi.json" <<'PY'
import json,sys; d=json.load(open(sys.argv[1]))
for m,v in d['modules'].items(): print("module", m, "functions", sorted(v['functions']))
print("lib/internal/helper in interface:", 'lib/internal/helper' in d['modules'], "| lib.sneaky (@internal) in interface:", 'sneaky' in d['modules']['lib']['functions'])
PY
)
