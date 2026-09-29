#!/usr/bin/env bash
# Probe 5: Gleam 1.12.0, offline (no hex, no stdlib).
# EXPECTED (stated before the run):
#  5a @external(erlang, "Elixir.Nope", "count") to a module that exists nowhere: `gleam build` SUCCEEDS (Gleam never checks the Erlang module exists).
#  5b gleam.toml [dependencies] gleam_json with no network: `gleam build` FAILS at dependency resolution/download, before compiling any source.
#  5c `import nope_pkg/thing` for a module in no declared package: `gleam build` FAILS with an unknown-module error naming the import,
#     pointing at gleam.toml dependencies. (This is a Gleam-source-level check, unlike 5a.)
G=${GLEAM:-/tmp/claude-0/tools/gleam}
here=$(cd "$(dirname "$0")" && pwd); cd "$here"
for p in a_external b_dep c_import; do rm -rf $p/build $p/manifest.toml; echo "=== $p"; (cd $p && timeout 90 $G build 2>&1 | head -25; echo "exit=${PIPESTATUS[0]}"); done
echo "=== 5a: does the compiled beam call the missing module? (it should: erlang file exists)"
find a_external/build -name '*.erl' | head -3 | while read f; do grep -n 'Elixir.Nope' "$f"; done
