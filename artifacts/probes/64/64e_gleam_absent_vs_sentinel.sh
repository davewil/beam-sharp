#!/usr/bin/env bash
# PROBE 64e — Gleam: does the stdlib's API tell "absent" from "present holding the sentinel" at Dynamic?
# NOTE: the `Option(Dynamic)` and `Option(Option(Int))` blocks in the Gleam source are TRUE BY CONSTRUCTION (a constructor
# is not its payload); they are printed for illustration and are NOT cited as evidence. The evidence is the dict.get block
# and the decode.optional_field block, which call stdlib code over stored sentinels.
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
