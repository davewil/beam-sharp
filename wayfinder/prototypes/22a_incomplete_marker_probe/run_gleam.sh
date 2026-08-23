#!/usr/bin/env bash
# Ticket 22 — how is the incomplete marker spelled, and WHERE does it go?
#
# Gleam is the only surveyed language whose unfinished-marker is a KEYWORD
# rather than a library call or an exception, so it is the strongest possible
# case for ticket 22's keyword arm. This measures four things:
#
#   A  does `todo` compile, and at what severity?
#   B  CONTROL: does the same harness reject a known type error? Without this,
#      A's exit 0 means nothing (borrow-heuristic memory, ticket 45).
#   C  can a marker sit on the DECLARATION — a function with no body at all?
#   D  can CI refuse the marker with a flag rather than a text search?
set -uo pipefail
cd "$(dirname "$0")/gleam_todo" || exit 1
SRC=src

banner() { printf '\n########## %s ##########\n' "$1"; }

banner "A: gleam build, todo in body position"
gleam build 2>&1 | grep -E 'Todo found|I think its type|error|Compiled' | sed 's/\x1b\[[0-9;]*m//g'
echo "EXIT_A=${PIPESTATUS[0]}"

banner "B: CONTROL — a known type error must be reported"
cp "$SRC/control_type_error.gleam.off" "$SRC/control_type_error.gleam"
gleam build 2>&1 | grep -E 'error|Type mismatch|Compiled' | sed 's/\x1b\[[0-9;]*m//g' | head -5
echo "EXIT_B=${PIPESTATUS[0]}"
rm -f "$SRC/control_type_error.gleam"

banner "C: marker in DECLARATION position — fn with no body"
cp "$SRC/no_body_decl.gleam.off" "$SRC/no_body_decl.gleam"
gleam build 2>&1 | grep -E 'error|Syntax|expected|Compiled' | sed 's/\x1b\[[0-9;]*m//g' | head -6
echo "EXIT_C=${PIPESTATUS[0]}"
rm -f "$SRC/no_body_decl.gleam"

banner "D: can CI refuse the marker with a flag?"
rm -rf build
gleam build --warnings-as-errors 2>&1 | grep -E 'Todo found|error|abort|Compiled' | sed 's/\x1b\[[0-9;]*m//g' | head -6
echo "EXIT_D=${PIPESTATUS[0]}"
