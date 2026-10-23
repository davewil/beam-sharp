#!/usr/bin/env bash
# PROBE 64e — Gleam: does the stdlib's API tell "absent" from "present holding the sentinel" at Dynamic?
# Builds a throwaway project in a temp dir with gleam_stdlib as a PATH dependency ($REF/stdlib; hex is blocked).
set -uo pipefail
: "${REF:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/proj/src" && cp "$HERE/64e_gleam/src/probe64.gleam" "$W/proj/src/"
cat > "$W/proj/gleam.toml" <<T
name = "probe64"
version = "1.0.0"
target = "erlang"
[dependencies]
gleam_stdlib = { path = "$REF/stdlib" }
T
echo "gleam_stdlib at $(git -C "$REF/stdlib" rev-parse --short HEAD); $(gleam --version)"
( cd "$W/proj" && gleam run 2>&1 | grep -v '^ *\(Compiling\|Compiled\|Running\|Downloading\|Resolving\|Added\)' )
