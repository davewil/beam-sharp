#!/usr/bin/env bash
# Ticket 60: what do neighbouring BEAM languages enforce about WHO may name a module?
# (a) Gleam internal_modules / @internal across a package boundary and inside one.
# (b) Elixir @moduledoc false: does it stop a caller?   (c) Erlang: any equivalent in erlc?
export PATH=/tmp/tools:$PATH
W=$(mktemp -d); cd "$W"
echo "=== (a) Gleam: library package 'lib' with internal modules, consumer package 'app' depending on it by path"
mkdir -p lib/src/lib/internal app/src
cat > lib/gleam.toml <<'EOF'
name = "lib"
version = "1.0.0"
target = "erlang"
internal_modules = ["lib/internal", "lib/internal/*"]
EOF
cat > lib/src/lib/internal/secret.gleam <<'EOF'
pub fn helper() -> Int { 42 }
EOF
cat > lib/src/lib.gleam <<'EOF'
import lib/internal/secret
pub fn api() -> Int { secret.helper() }
EOF
cat > app/gleam.toml <<'EOF'
name = "app"
version = "1.0.0"
target = "erlang"
[dependencies]
lib = { path = "../lib" }
EOF
echo "--- consumer uses the public module only:"
cat > app/src/app.gleam <<'EOF'
import lib
pub fn main() { lib.api() }
EOF
(cd app && gleam build 2>&1 | tail -2)
echo "--- consumer names the internal module:"
cat > app/src/app.gleam <<'EOF'
import lib/internal/secret
pub fn main() { secret.helper() }
EOF
(cd app && gleam build 2>&1 | grep -v '^\s*$' | head -12; echo "gleam exit=${PIPESTATUS[0]}")
echo "--- the SAME package naming its own internal module from a sibling (lib/src/lib.gleam above) built fine:"
(cd lib && gleam build 2>&1 | tail -1)
echo "--- @internal on a single pub function: does a consumer get refused?"
cat > lib/src/lib/other.gleam <<'EOF'
@internal
pub fn only_for_friends() -> Int { 1 }
pub fn open() -> Int { 2 }
EOF
cat > app/src/app.gleam <<'EOF'
import lib/other
pub fn main() { other.only_for_friends() }
EOF
(cd app && gleam build 2>&1 | grep -v '^\s*$' | head -6; echo "gleam exit=${PIPESTATUS[0]}")
echo
echo "=== (b) Elixir: @moduledoc false (the 'internal' convention) -- does a caller get any diagnostic?"
cat > i.ex <<'EOF'
defmodule Lib.Internal do
  @moduledoc false
  def helper, do: 42
end
defmodule Consumer do
  def f, do: Lib.Internal.helper()
end
EOF
elixirc i.ex 2>&1 | head -3; echo "elixirc exit=${PIPESTATUS[0]} (no output = no diagnostic)"
echo
echo "=== (c) Erlang: -export is the only gate; any export is callable from anywhere"
cat > a.erl <<'EOF'
-module(a). -export([f/0]). f() -> b:g().
EOF
cat > b.erl <<'EOF'
-module(b). -export([g/0]). g() -> 1.
EOF
erlc a.erl b.erl; echo "erlc exit=$?"
