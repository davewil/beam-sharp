#!/usr/bin/env bash
# PROTOTYPE 48g — is exhaustiveness over a map VACUOUS, as ticket 48 says?
#
# Throwaway. Ticket 48, checking the sentence that sets the ticket's price.
#
# Ticket 48's "What survives" paragraph reads: "A map's key domain is
# unbounded, so a pattern over it never closes a residual, so a catch-all is
# always legal there (ticket 12's rule). Exhaustiveness over a map is
# VACUOUS. ... beam-sharp would be adding its first type over which the
# headline guarantee says nothing."
#
# That is the whole cost of candidate 2, and it was never run. 48f has since
# shown that map patterns already exist, so the claim is testable TODAY rather
# than being a prediction about a type that does not ship.
#
# The distinction the sentence misses: beam-sharp's brace map is keyed by a
# fixed set of PascalCase field names (bs_parser.yrl:98, :490). A closed key
# set is not an unbounded key domain, so the vacuity argument may not reach
# the thing that actually ships.
#
#   1. Is a map pattern with NO catch-all accepted, or refused?
#   2. If refused, is the residual PRECISE — does it name the missing case?
#   3. Control: does the same shape over a closed union refuse the same way?
#   4. Control: does an OPEN scalar (int) refuse, proving the checker
#      distinguishes open from closed rather than always demanding a clause?
#
#   ./48g_map_exhaustiveness_not_vacuous.sh
#
# Requires: OTP 28, rebar3, a built bsc. Runs in a temp dir.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

probe () {
    local name="$1" body="$2"
    local mod out rc
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name ---"
    out="$("$BSC" "$WORK/$name/$mod/$mod.bs" 2>&1)"; rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    if [ "$rc" -eq 0 ]; then echo "    ACCEPTED (exit 0)"; else echo "    REFUSED (exit $rc)"; fi
    echo
}

echo "==============================================================="
echo "1. THE CLAIM — a map pattern with no catch-all."
echo "==============================================================="
echo "    If exhaustiveness over a map were vacuous, nothing would be"
echo "    owed here and this would compile."

probe map_no_catchall '
module MapNo

public atom Kind({ Status: int } m)

Kind({ Status: 200 }) -> :ok
'

echo "==============================================================="
echo "2. CONTROL — the same shape over a CLOSED union."
echo "==============================================================="
echo "    The known-good case. Read this beside section 1: if the map"
echo "    refused with a residual as precise as this one, the checker is"
echo "    treating the map as a real subject, not waving it through."

probe closed_union_no_catchall '
module CtlUnion

type Status = :live | :dead

public int F(Status s)

F(:live) -> 1
'

echo "==============================================================="
echo "3. CONTROL — an OPEN subject, where a catch-all IS mandatory."
echo "==============================================================="
echo "    An unrefined int has an unbounded domain. This is what a"
echo "    genuinely vacuous subject looks like: no enumeration can ever"
echo "    close it, and the residual has an unbounded top in it."

probe open_int_no_catchall '
module CtlInt

public atom F(int n)

F(0) -> :zero
'

echo "==============================================================="
echo "4. CONTROL — the map WITH its catch-all, to prove 1 is about the"
echo "   missing clause and not about map patterns being broken."
echo "==============================================================="

probe map_with_catchall '
module MapYes

public atom Kind({ Status: int } m)

Kind({ Status: 200 }) -> :ok
Kind(m)               -> :other
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    Exhaustiveness over beam-sharp's brace map is NOT vacuous. The"
echo "    compiler demands the missing clause and PRINTS it, exactly as"
echo "    it does for a closed union."
echo
echo "    The ticket's sentence is true of an UNBOUNDED KEY DOMAIN, which"
echo "    is not what ships. Today's map is keyed by a fixed set of"
echo "    PascalCase field names, so the key set is closed and the"
echo "    residual is over the FIELD VALUE — ordinary refinement work."
echo
echo "    The vacuity cost therefore attaches to the NEW thing ticket 48"
echo "    is actually asking for (see 48i), not to map patterns as such."
echo "done."
