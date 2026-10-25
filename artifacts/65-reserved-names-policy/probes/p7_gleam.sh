#!/usr/bin/env bash
# P7: gleam 1.19.1: local module named like a stdlib module (gleam/list), like a prelude module, and a type named like a prelude type.
# No hex access, so the project has NO dependencies: gleam_stdlib is unavailable (source unavailable: hex.pm blocked) and
# `gleam/list` cannot be shown as an import. What CAN be tested: compiler-owned prelude names and module-name rules.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
D=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p7; rm -rf $D; mkdir -p $D; cd $D
gleam --version
gleam new --skip-git --skip-github probe >/dev/null 2>&1; cd probe
cat > gleam.toml <<'X'
name = "probe"
version = "1.0.0"
target = "erlang"
X
rm -rf test; mkdir -p src
try(){ echo "=== $1"; gleam build 2>&1 | grep -v "^ *Compiling\|^ *Compiled in\|^ *Resolving\|Downloading\|Downloaded" | head -${3:-14}; echo "exit=${PIPESTATUS[0]}"; }
cat > src/probe.gleam <<'X'
pub fn main() { 1 }
X
try "control: empty project builds"
# 1. type named like prelude types
cat > src/probe.gleam <<'X'
pub type Result(a, b) { Ok(a) Error(b) }
pub type List(a) { Nil }
pub fn main() { Ok(1) }
X
try "user type Result/List shadowing prelude types (and constructors Ok/Error/Nil)"
cat > src/probe.gleam <<'X'
pub type Bool { True False Maybe }
pub fn main(b: Bool) { case b { True -> 1 False -> 0 Maybe -> 2 } }
X
try "user type Bool with constructors True/False"
# 2. module named like erlang / stdlib-ish modules
for m in gleam/list list gleam/erlang erlang lists maps gleam; do
  rm -f src/*.gleam; mkdir -p src/$(dirname $m); printf 'pub fn f() { 1 }\n' > src/$m.gleam; printf 'pub fn main() { 1 }\n' > src/probe.gleam
  try "local module src/$m.gleam"; rm -rf src/gleam src/list.gleam src/lists.gleam src/maps.gleam src/erlang.gleam
done
