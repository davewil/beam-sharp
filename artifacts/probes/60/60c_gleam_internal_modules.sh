#!/usr/bin/env bash
# PROBE 60c -- ticket 60 (ENG-242). Claim: Gleam's `internal_modules` (gleam.toml) and `@internal`
# are NOT a caller check. gleam 1.18.1, no network, path dependency only (no hex deps).
#   G1. An app importing `liba/internal/helper` (default internal path, from a path dep) builds, exit 0.
#   G2. An app importing a module listed in `internal_modules = ["liba/secret"]` builds, exit 0.
#   G3. An `@internal pub fn` is callable from the dependent package, exit 0.
#   G4. CONTROL: importing a non-`pub` function IS refused (the "what" half), exit != 0.
#   G5. `gleam docs build`: does the generated docs index link the internal modules? (printed; read it)
# The gleam compiler SOURCES are not installed (conda binary only): behaviour is cited from output.
set -uo pipefail
command -v gleam >/dev/null || { echo "gleam missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/liba/src/liba/internal" "$W/liba/src/liba/secret" "$W/appb/src"
cat > "$W/liba/gleam.toml" <<'E'
name = "liba"
version = "1.0.0"
internal_modules = ["liba/internal", "liba/secret"]
E
cat > "$W/liba/src/liba.gleam" <<'E'
import liba/internal/helper
import liba/secret/vault
pub fn api() -> Int { helper.help() + vault.key() + marked() + hidden() }
@internal
pub fn marked() -> Int { 3 }
fn hidden() -> Int { 4 }
E
echo 'pub fn help() -> Int { 1 }' > "$W/liba/src/liba/internal/helper.gleam"
echo 'pub fn key() -> Int { 2 }'  > "$W/liba/src/liba/secret/vault.gleam"
cat > "$W/appb/gleam.toml" <<'E'
name = "appb"
version = "1.0.0"
[dependencies]
liba = { path = "../liba" }
E
try() { # label, source
  printf '%s\n' "$2" > "$W/appb/src/appb.gleam"; rm -rf "$W/appb/build"
  out=$(cd "$W/appb" && gleam build 2>&1); rc=$?
  echo "$1: exit=$rc"; echo "$out" | grep -E '^error|^warning' | head -3
}
(cd "$W/liba" && gleam build >/dev/null 2>&1; echo "liba itself (imports its own internal modules): exit=$?")
try "G1 import liba/internal/helper"   $'import liba/internal/helper\npub fn main() { helper.help() }'
try "G2 import liba/secret/vault"      $'import liba/secret/vault\npub fn main() { vault.key() }'
try "G3 call @internal liba.marked"    $'import liba\npub fn main() { liba.marked() }'
try "G4 CONTROL non-pub liba.hidden"   $'import liba\npub fn main() { liba.hidden() }'
echo "--- G5 docs of liba"
(cd "$W/liba" && gleam docs build >/dev/null 2>&1; echo "docs exit=$?"; ls build/dev/docs/liba 2>/dev/null | grep -i -E 'html$' ; echo "sidebar/index links containing 'internal' or 'secret':"; grep -o -i -E 'href="[^"]*(internal|secret)[^"]*"' build/dev/docs/liba/index.html build/dev/docs/liba/liba.html | sort -u | head -5; echo "(end)")
