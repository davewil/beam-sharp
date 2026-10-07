#!/bin/sh
# Gleam 1.19.0: does `internal_modules` / `@internal` refuse a dependent package? Rebuilds from scratch.
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$(dirname "$0")" || exit 1
rm -rf lib_pkg app_pkg; mkdir -p lib_pkg/src/lib_pkg/internal app_pkg/src
cat > lib_pkg/gleam.toml <<'T'
name = "lib_pkg"
version = "1.0.0"
description = "probe"
licences = ["Apache-2.0"]
internal_modules = ["lib_pkg/internal", "lib_pkg/internal/*"]
T
cat > lib_pkg/src/lib_pkg.gleam <<'T'
import lib_pkg/internal/helper
pub fn total(x: Int) -> Int { helper.recompute(x) }
@internal
pub fn tagged(x: Int) -> Int { x }
T
cat > lib_pkg/src/lib_pkg/internal/helper.gleam <<'T'
pub fn recompute(x: Int) -> Int { x + 1 }
T
cat > app_pkg/gleam.toml <<'T'
name = "app_pkg"
version = "1.0.0"
[dependencies]
lib_pkg = { path = "../lib_pkg" }
T
cat > app_pkg/src/app_pkg.gleam <<'T'
import lib_pkg
import lib_pkg/internal/helper
pub fn main() { helper.recompute(1) + lib_pkg.tagged(2) }
T
echo "== app_pkg imports lib_pkg/internal/helper AND calls the @internal fn"
(cd app_pkg && gleam build 2>&1; echo "[exit $?]")
echo "== lib_pkg docs: is the internal module rendered?"
(cd lib_pkg && gleam docs build >/dev/null 2>&1; ls build/dev/docs/lib_pkg/*.html; grep -c "recompute\|helper" build/dev/docs/lib_pkg/*.html)
rm -rf lib_pkg/build app_pkg/build
