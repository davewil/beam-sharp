#!/usr/bin/env bash
# Ticket 22 — "if the incomplete marker is not implemented, what's the cost?"
# (David, 2026-08-23). Measures it rather than asserting it.
#
#   1  does a stub SUPPRESS other diagnostics in its module?  (StubMixed vs
#      StubMixedControl — same file, same planted defect, stub removed)
#   2  does a module with one unwritten function EMIT a .beam? (StubBlocks is
#      correct apart from the stub, so nothing else can be blamed)
#   3  does `--api` still answer for that module? 23 §7 is quoted in
#      bs_api.erl to justify answering for a half-written module, while
#      bs_check refuses to compile it — so they may disagree.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BSC="$HERE/../../../compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || { echo "build first: cd compiler && rebar3 escriptize"; exit 1; }
OUT="${TMPDIR:-/tmp}/bs_t22_cost.$$"

banner() { printf '\n########## %s ##########\n' "$1"; }

banner "1a: stub + planted defect — are BOTH reported?"
rm -rf "$OUT"; mkdir -p "$OUT"
"$BSC" -o "$OUT" "$HERE/bs/StubMixed"/*.bs 2>&1 | grep -c 'error:' | sed 's/^/errors reported: /'

banner "1b: CONTROL, same defect, stub deleted"
rm -rf "$OUT"; mkdir -p "$OUT"
"$BSC" -o "$OUT" "$HERE/bs/StubMixedControl"/*.bs 2>&1 | grep -c 'error:' | sed 's/^/errors reported: /'

banner "2: correct module + ONE unwritten function — is a .beam emitted?"
rm -rf "$OUT"; mkdir -p "$OUT"
"$BSC" -o "$OUT" "$HERE/bs/StubBlocks"/*.bs 2>&1 | head -3
echo "EXIT=$?"
echo "beam files emitted: $(find "$OUT" -name '*.beam' | wc -l | tr -d ' ')"

banner "3: does --api answer for the same half-written module?"
"$BSC" --api "$HERE/bs/StubBlocks"/*.bs 2>&1 | head -20
echo "EXIT=$?"

rm -rf "$OUT"
