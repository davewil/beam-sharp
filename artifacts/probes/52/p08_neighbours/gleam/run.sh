#!/bin/sh
# p08/gleam: where does a Gleam program say what it needs, and what does the compiler do when it is missing?
# NOTE: repo.hex.pm is blocked by the sandbox egress proxy, so `gleam add` / dependency download cannot run here.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 HOME=$(mktemp -d)
T=$(mktemp -d); cd $T
echo "## 1. real 'gleam new demo' -> gleam.toml"
gleam new demo --skip-git --skip-github 2>&1 | tail -2; cat -n demo/gleam.toml | grep -v "^ *[0-9]*\s*#" | grep -v "^ *[0-9]*\s*$"
echo "## 2. 'gleam add' (needs hex)"; ( cd demo && timeout 40 gleam add gleam_http 2>&1 | tail -4 )
echo "## 3. the SOURCE says only module paths: import gleam/io (package gleam_stdlib is in gleam.toml [dependencies])"
cat demo/src/demo.gleam
echo "## 4. strip the dependency from gleam.toml, keep the import: compile-time diagnostic"
rm -rf demo/test
cat > demo/gleam.toml <<'X'
name = "demo"
version = "1.0.0"
X
cat > demo/src/demo.gleam <<'X'
import gleam/io

pub fn main() {
  io.println("hi")
}
X
( cd demo && timeout 60 gleam build 2>&1 | head -20 )
echo "## 5. an @external names module+function, never a package"
cat > demo/src/demo.gleam <<'X'
@external(erlang, "crypto", "hash")
pub fn hash(kind: Int, data: String) -> String

pub fn main() { hash(1, "x") }
X
( cd demo && timeout 60 gleam build 2>&1 | head -8; echo "gleam build rc=$?" )
echo "## 6. where Gleam records an OTP app that only @external reaches: gleam.toml [erlang] extra_applications -> generated .app"
( cd demo && cat gleam.toml > gleam.toml.bak; printf '\n[erlang]\nextra_applications = ["crypto"]\n' >> gleam.toml; timeout 60 gleam build 2>&1 | tail -1
  echo "-- demo.app WITH extra_applications = ["crypto"]:"; grep -n "applications" build/dev/erlang/demo/ebin/demo.app
  cp gleam.toml.bak gleam.toml; timeout 60 gleam build >/dev/null 2>&1; rm -f build/dev/erlang/demo/ebin/demo.app; timeout 60 gleam build >/dev/null 2>&1; echo "-- without extra_applications:"; grep -n "applications" build/dev/erlang/demo/ebin/demo.app )
