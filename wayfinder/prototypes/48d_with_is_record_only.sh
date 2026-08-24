#!/usr/bin/env bash
# PROTOTYPE 48d — is `with` already the map-update form, or is it record-only?
#
# Throwaway. Ticket 48, checking a claim the SURVEY ITSELF made.
#
# 48a relocated the Erlang `:=` / `=>` question out of pattern position and
# into UPDATE position. The survey's first draft then concluded "...and
# beam-sharp already has that form — `with`". That is a claim about THIS
# compiler, and it was written without running THIS compiler, which is the
# failure the repo's own rules exist to prevent.
#
# The doubt was specific. `with` updates a RECORD. A record's field set is
# closed and statically known, so "the key might be absent" cannot arise — the
# field is in the type or it is not. Erlang needs `:=` versus `=>` precisely
# because a map's key domain is DYNAMIC.
#
# The answer turned out to be worse than either option: `with` is record-only
# in intent, and its SUBJECT is not checked at all.
#
#   ./48d_with_is_record_only.sh
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

# One directory per probe, named after the module — F15's rule. Exit status is
# printed for every probe, because on this compiler a SILENT run is a PASS and
# an empty section would otherwise be unreadable.
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
echo "0. TWO CONTROLS — is the checker even looking at this position?"
echo "==============================================================="
echo "    A silent pass is this compiler's success signal, so an unchecked"
echo "    construct and a correct one look identical. These two establish"
echo "    that the checker DOES reach a function body and DOES understand"
echo "    \`with\`. Without them, every ACCEPTED below is unreadable."

probe control_a_with_on_record '
module CtlA

record Order { Status: atom, Total: int }

public Order Bump(Order o)

Bump({ Total: t } o) -> o with { Total = t + 1 }
'

probe control_b_with_wrong_field '
module CtlB

record Order { Status: atom, Total: int }

public Order Bump(Order o)

Bump(o) -> o with { NoSuchField = 1 }
'

probe control_c_return_type '
module CtlC

public int F(int n)

F(n) -> :not_an_int
'

echo "    Read those three together: the checker reaches a function body"
echo "    (C refuses a bad return), and it understands \`with\` well enough"
echo "    to name a record's fields (B refuses an undeclared one). So an"
echo "    ACCEPTED below is a real acceptance, not a blind spot in the probe."
echo

echo "==============================================================="
echo "1. Does \`with\` accept a list of pairs — the thing that carries"
echo "   an open key/value channel today?"
echo "==============================================================="

probe on_assoc_list '
module OnAssoc

public list<(atom, term)> Put(list<(atom, term)> m)

Put(m) -> m with { Key = 1 }
'

echo "==============================================================="
echo "2. Does \`with\` accept a bare term — a foreign map off the FFI?"
echo "==============================================================="

probe on_term '
module OnTerm

public term Put(term m)

Put(m) -> m with { Key = 1 }
'

echo "==============================================================="
echo "3. THE ONE THAT SETTLES IT — does \`with\` accept an INT?"
echo "==============================================================="
echo "    \`n with { Key = 1 }\` where n : int is not a design question."
echo "    It is nonsense. If this is accepted, then \`with\`'s subject is"
echo "    not checked at all, and probes 1 and 2 above are measuring a"
echo "    HOLE rather than support for map update."

probe on_int '
module OnInt

public int F(int n)

F(n) -> n with { Key = 1 }
'

echo "==============================================================="
echo "4. Is there any map/dict type to name in the first place?"
echo "==============================================================="

probe declare_map '
module DeclMap

record Holder { M: map<atom, int> }

public int Zero()

Zero() -> 0
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    \`with\` is record-only in INTENT — control B proves the compiler"
echo "    knows a record's field set and refuses an undeclared field."
echo "    But its SUBJECT is unchecked: an int, a term and a list of pairs"
echo "    are all accepted, and the int case cannot be anything but a bug."
echo
echo "    So beam-sharp does NOT already have a map-update form. It has a"
echo "    RECORD-update form with a missing subject check. The Erlang"
echo "    ':=' vs '=>' question relocates to a construct that would have"
echo "    to be ADDED, not one that exists."
echo "done."
