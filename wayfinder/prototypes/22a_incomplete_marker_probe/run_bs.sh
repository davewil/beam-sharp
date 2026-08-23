#!/usr/bin/env bash
# Ticket 22 — B# itself. The survey (run_gleam.sh, run_csharp.sh,
# run_erlang.sh) is unanimous that the unfinished-marker goes in BODY
# position. This asks what body position COSTS in B#, which unlike every
# surveyed language is multi-clause with an exhaustiveness checker.
#
#   none      — signature, no clauses. B# today.
#   partial   — inexhaustive. What a residual looks like. Doubles as the
#               CONTROL: if this is silent, the checker is not looking and
#               the `catchall` result below means nothing.
#   catchall  — `Weigh(_) -> 0`. Does the catch-all consume the residual
#               that 23 §7 calls the whole value of a stub?
#
# One directory per case: F15 makes a directory a module, so three .bs files
# in one directory are three names for one module, and the compiler says so.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BSC="$HERE/../../../compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || { echo "build first: cd compiler && rebar3 escriptize"; exit 1; }
OUT="${TMPDIR:-/tmp}/bs_t22_out.$$"
mkdir -p "$OUT"

for d in StubNone StubPartial StubCatchall StubBound StubRecord; do
  printf '\n########## %s ##########\n' "$d"
  "$BSC" -o "$OUT" "$HERE/bs/$d"/*.bs 2>&1 | head -10
  echo "EXIT=${PIPESTATUS[0]}"
done
rm -rf "$OUT"
