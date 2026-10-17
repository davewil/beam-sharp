#!/usr/bin/env bash
# P8: Gleam 1.12.0 — where does a dependency live, and what does the compiler do with it?
# Uses path dependencies only (hex.pm is unreachable from this box).
set -u; . "$(dirname "$0")/common.sh"
cd $WORK; mkdir -p leaf/src mid/src g/src
printf 'name = "leaf"\nversion = "1.0.0"\n' > leaf/gleam.toml;  echo 'pub fn go() { 1 }' > leaf/src/leaf.gleam
printf 'name = "mid"\nversion = "1.0.0"\n[dependencies]\nleaf = { path = "../leaf" }\n' > mid/gleam.toml
printf 'import leaf\npub fn go() { leaf.go() }\n' > mid/src/mid.gleam
printf 'name = "g"\nversion = "1.0.0"\n[dependencies]\nmid = { path = "../mid" }\n' > g/gleam.toml
cd g
echo "--- (a) import of a module that no package provides"
printf 'import nothere/thing\npub fn main() { thing.go() }\n' > src/g.gleam; gleam build 2>&1 | grep -A1 -m2 "error:\|No module"
echo "--- (b) import of a module from a TRANSITIVE-only package (leaf, via mid)"
printf 'import leaf\npub fn main() { leaf.go() }\n' > src/g.gleam; gleam build 2>&1 | grep -A5 "warning:" | head -7
echo "--- (c) import of a declared direct dependency"
printf 'import mid\npub fn main() { mid.go() }\n' > src/g.gleam; gleam build 2>&1 | tail -1
