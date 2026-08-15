#!/usr/bin/env bash
#
# Keep wayfinder/map.md an INDEX.
#
# WHY THIS EXISTS
# On 2026-08-15 the map was split from 1,564 lines to ~284: a destination, the
# working notes, and a tagged index, with the bodies moved to decisions.md,
# fog.md and scope.md beside it.
#
# It needed splitting because it carried a contract it had stopped keeping. Its
# own comment promised "one line per closed ticket: enough to judge relevance,
# then open the ticket for detail", and entries had reached 127 lines. NOTHING
# ENFORCED THAT CONTRACT, which is exactly why it rotted — the same failure that
# let 63 exemplar clause heads sit in a dialect the language no longer had, and
# let LANGUAGE.md claim `true` was shipped when the lexer disagreed. Prose is not
# gated; this is the gate.
#
# WHY IT IS A SCRIPT AND NOT AN EUNIT TEST
# David, 2026-08-15: "map.md size is not a concern of the test suite." The
# compiler's suite tests the compiler — source text in, a callable .beam out.
# The map is a wayfinder concern, so it is gated the way LANGUAGE.md is: by a
# script in bin/ that a human or CI runs.
#
# WHAT IT CHECKS
#   1. map.md stays within a line budget.
#   2. no INDEX entry outgrows the index — this is the one that matters, since a
#      budget only notices long after an entry started sprawling.
#   3. the three body files exist and the index still points at each.
#
# Usage:  bin/check-map.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$HERE/wayfinder/map.md"
BUDGET=350
ENTRY_MAX=4

[ -f "$MAP" ] || { echo "no map at $MAP" >&2; exit 2; }

fail=0

# --- 1. the budget ------------------------------------------------------------
lines=$(wc -l < "$MAP" | tr -d ' ')
if [ "$lines" -le "$BUDGET" ]; then
    printf '  %-10s map.md is %s lines (budget %s)\n' "ok" "$lines" "$BUDGET"
else
    printf '  %-10s map.md is %s lines, over the %s budget\n' "OVER" "$lines" "$BUDGET"
    echo "             the bodies belong in decisions.md / fog.md / scope.md"
    fail=1
fi

# --- 2. per-entry, and it fails BY NAME ---------------------------------------
# A bare "it is too long" is a puzzle; naming the entries is a diagnosis. Same
# bargain as the surface-form gate in the compiler suite.
#
# The index starts at the first "## Decisions so far" heading — anchored on the
# heading rather than a line number, so inserting notes above it cannot silently
# empty this check. If that heading vanishes the gate fails rather than passing
# on nothing, which is the trap a green suite hides.
if ! grep -q '^## Decisions so far' "$MAP"; then
    echo "  MISSING    no '## Decisions so far' heading — the index gate cannot anchor" >&2
    exit 1
fi

fat="$(awk -v max="$ENTRY_MAX" '
    /^## Decisions so far/ { inindex = 1 }
    !inindex { next }
    /^- / {
        if (title != "" && len > max) print len " lines: " title
        title = $0
        sub(/^- \*\*/, "", title); sub(/\*\*.*/, "", title)
        len = 1; next
    }
    /^#/ || /^---/ {
        if (title != "" && len > max) print len " lines: " title
        title = ""; next
    }
    title != "" { len++ }
    END { if (title != "" && len > max) print len " lines: " title }
' "$MAP")"

if [ -z "$fat" ]; then
    printf '  %-10s every index entry is %s lines or fewer\n' "ok" "$ENTRY_MAX"
else
    printf '  %-10s these entries outgrew the index:\n' "FAT"
    echo "$fat" | sed 's/^/             /'
    echo "             move the body to decisions.md / fog.md / scope.md and leave a link"
    fail=1
fi

# --- 3. the split is still intact ---------------------------------------------
for f in decisions.md fog.md scope.md; do
    if [ ! -f "$HERE/wayfinder/$f" ]; then
        printf '  %-10s wayfinder/%s is missing\n' "GONE" "$f"; fail=1
    elif ! grep -q "$f" "$MAP"; then
        printf '  %-10s wayfinder/%s exists but the map does not link it\n' "ORPHAN" "$f"; fail=1
    else
        printf '  %-10s wayfinder/%s present and linked\n' "ok" "$f"
    fi
done

echo
[ "$fail" -eq 0 ] && echo "map is an index" || { echo "map has stopped being an index"; exit 1; }
