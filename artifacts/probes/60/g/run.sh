#!/usr/bin/env bash
# 60/g : what Gleam actually enforces for @internal and gleam.toml internal_modules. EXECUTED RUN (no compiler source installed).
# Two path-dependent packages, no hex access needed (no stdlib). Needs env.sh (gleam on PATH).
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
gleam --version
mkdir -p lib/src/lib lib/src/lib/internal lib/test app/src app/test
cat > lib/gleam.toml <<'EOF'
name = "lib"
version = "1.0.0"
internal_modules = ["lib/internal", "lib/internal/*"]
EOF
cat > lib/src/lib.gleam <<'EOF'
pub fn api() -> Int { helper() + 1 }

// a PUBLIC (non-internal) function whose signature mentions the @internal type
pub fn leak() -> Secret { Secret(1) }

@internal
pub fn helper() -> Int { 41 }

@internal
pub type Secret { Secret(Int) }
EOF
cat > lib/src/lib/internal/deep.gleam <<'EOF'
pub fn deep() -> Int { 7 }
EOF
cat > lib/src/lib/uses_own.gleam <<'EOF'
import lib
import lib/internal/deep
pub fn ok() -> Int { deep.deep() + lib.helper() }
EOF
cat > lib/test/lib_test.gleam <<'EOF'
import lib
import lib/internal/deep
pub fn main() -> Int { lib.helper() + deep.deep() }
EOF
cat > app/gleam.toml <<'EOF'
name = "app"
version = "1.0.0"
[dependencies]
lib = { path = "../lib" }
EOF
cat > app/src/app.gleam <<'EOF'
import lib
import lib/internal/deep
pub fn main() -> Int { lib.api() + lib.helper() + deep.deep() }
pub fn mk() -> lib.Secret { lib.Secret(1) }
EOF
echo "== 1. lib on its own: @internal + internal_modules used INSIDE the package, including its own test/"
(cd lib && rm -rf build && gleam build 2>&1 | tail -30; echo "exit=${PIPESTATUS[0]}")
echo "== 1b. gleam check (also compiles test/): lib/test/lib_test.gleam names @internal and internal_modules"
(cd lib && gleam check 2>&1 | tail -10; echo "exit=${PIPESTATUS[0]}")
echo "== 2. app (separate package, path dependency) names lib.helper (@internal), lib/internal/deep, lib.Secret (@internal type)"
(cd app && rm -rf build && gleam build 2>&1 | tail -60; echo "exit=${PIPESTATUS[0]}")
echo "== 3. what @internal does DO: gleam docs build hides it (the only other effect)"
(cd lib && gleam docs build 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"; grep -l 'helper' build/dev/docs/lib/*.html build/dev/docs/lib/*/*.html 2>/dev/null | head; grep -o 'api\|helper\|leak' build/dev/docs/lib/lib.html 2>/dev/null | sort | uniq -c)
echo "== 4. the BEAM side: is the @internal function still in the .beam export table?"
(cd lib && erl -noshell -pa build/dev/erlang/lib/ebin -eval 'io:format("~p~n",[lib:module_info(exports)]), halt().')
