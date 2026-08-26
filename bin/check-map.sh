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
# `CHECK_MAP_DIR` exists for the self-test below, which points this gate at
# mutated COPIES of the real wayfinder directory. Nothing else sets it. The
# copies are the real files with one defect introduced, so a control cannot
# pass by being simpler than the thing it stands in for — a hand-built fixture
# map would satisfy all four checks trivially and prove nothing about the ones
# that matter.
WAYFINDER="${CHECK_MAP_DIR:-$HERE/wayfinder}"
MAP="$WAYFINDER/map.md"
# RAISED 350 -> 365 on 2026-08-26, and the reason matters more than the number.
# The budget was not binding on sprawl; it was binding on ABSENCE. Reviewing
# ticket 37 found that 37, 25 and 60 had ticket files and no index entry at all
# — dropped by the 2026-08-15 split and never noticed — and at 349/350 the
# budget was the single thing preventing them from being added back. A budget
# that forces entries to be OMITTED rather than SHORTENED inverts this gate's
# purpose, so it moved. Check 2 (ENTRY_MAX) is the check that actually keeps
# this file an index, and it is unchanged.
BUDGET=365
ENTRY_MAX=4

[ -f "$MAP" ] || { echo "no map at $MAP" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR CHECKS, FOUR POSITIVE CONTROLS. Each red is required to carry that
# check's own marker — OVER, FAT, GONE, UNINDEXED — because any one of them
# would satisfy a bare "did it exit non-zero", and a gate that is right by
# coincidence is what ticket 15 lost a session to.
#
# Check 4 is the one worth having a control for at all: an index that is short,
# tidy and MISSING AN ENTRY passes the other three, which is precisely how
# ticket 39's body sat unreachable while this gate was green.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Output is CAPTURED, not piped: `set -o pipefail` is on and a control run
    # is supposed to exit 1, so `control … | grep` would report the failing
    # left-hand status even when the marker was found.
    control() {
        CHECK_MAP_DIR="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }
    fresh() {
        rm -rf "$1"; mkdir -p "$1"
        cp "$HERE/wayfinder/map.md" "$HERE/wayfinder/decisions.md" \
           "$HERE/wayfinder/fog.md" "$HERE/wayfinder/scope.md" "$1/"
    }

    st_fail=0
    expect() {   # expect <marker> <dir> <what the control built>
        case "$(control "$2")" in
            *"$1"*) ;;
            *) echo "SELF-TEST FAILED: $3 was not reported — the $1 check cannot fire"
               st_fail=1 ;;
        esac
    }

    # CONTROL 1 — a map over the line budget.
    fresh "$CTL/over"
    for _ in $(seq 1 "$((BUDGET + 10))"); do echo "padding" >> "$CTL/over/map.md"; done
    expect OVER "$CTL/over" "a map past its line budget"

    # CONTROL 2 — an index entry that outgrew the index. Extra body lines under
    # the first entry take it past ENTRY_MAX without touching anything else,
    # which is exactly how an entry sprawls in practice.
    #
    # IT MUST BE THE FIRST ENTRY **INSIDE THE INDEX**, not the first in the
    # file. The map opens with working notes that are also `- **` bullets, and
    # the first draft of this control fattened one of those — above the
    # `## Decisions so far` anchor, where the check deliberately does not look.
    # It reported "cannot fire" against a check that was working.
    fresh "$CTL/fat"
    awk '
        /^## Decisions so far/ { inindex = 1 }
        inindex && !done && /^- \*\*/ {
            print; print "  a"; print "  b"; print "  c"; print "  d"; done = 1; next
        }
        { print }
    ' "$CTL/fat/map.md" > "$CTL/fat/map.tmp" && mv "$CTL/fat/map.tmp" "$CTL/fat/map.md"
    expect FAT "$CTL/fat" "an index entry past its line limit"

    # CONTROL 3 — a body file that is gone.
    fresh "$CTL/gone"
    rm -f "$CTL/gone/fog.md"
    expect GONE "$CTL/gone" "a missing body file"

    # CONTROL 4 — a body entry with no way in from the index.
    fresh "$CTL/unindexed"
    printf '\n- **A body nothing indexes** — added by this gate.\n' >> "$CTL/unindexed/fog.md"
    expect UNINDEXED "$CTL/unindexed" "an unreachable body entry"

    # NEGATIVE CONTROL — the wayfinder directory as committed.
    fresh "$CTL/clean"
    if CHECK_MAP_DIR="$CTL/clean" "${BASH_SOURCE[0]}" > /dev/null 2>&1; then :; else
        echo "SELF-TEST FAILED: the map as committed was rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the over-budget map, the fat entry, the missing body"
        echo "           and the unindexed one; accepted the committed map — it discriminates"
        exit 0
    fi
    exit 1
fi

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
    if [ ! -f "$WAYFINDER/$f" ]; then
        printf '  %-10s wayfinder/%s is missing\n' "GONE" "$f"; fail=1
    elif ! grep -q "$f" "$MAP"; then
        printf '  %-10s wayfinder/%s exists but the map does not link it\n' "ORPHAN" "$f"; fail=1
    else
        printf '  %-10s wayfinder/%s present and linked\n' "ok" "$f"
    fi
done

# --- 4. every body has an index entry -----------------------------------------
# THE DRIFT CHECKS 1-3 CANNOT SEE.
#
# An index that is short, tidy and MISSING AN ENTRY passes every check above: the
# budget is fine, no entry is fat, the files are linked. Found 2026-08-15 while
# backfilling Linear — fog.md held 14 patch bodies and the map indexed 13. Ticket
# 39 had a body and no way in, so the only route to it was already knowing it
# existed, which is the one thing an index is for.
#
# Same failure family as the split itself: a contract nothing enforced. Checked
# body-to-index only; the reverse (an index entry whose body was deleted) is a
# different bug and has never happened.
missing=""
for body in decisions.md fog.md scope.md; do
    while IFS= read -r title; do
        [ -z "$title" ] && continue
        grep -Fq -- "**$title**" "$MAP" || missing="$missing$body: $title"$'\n'
    done < <(awk '
        /<details>/  { archived = 1 }
        /<\/details>/{ archived = 0; next }
        archived     { next }
        /^- \*\*/    { print }
    ' "$WAYFINDER/$body" \
        | sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' \
        | sed 's/[.,]$//')
done

if [ -z "$missing" ]; then
    printf '  %-10s every body entry has an index entry\n' "ok"
else
    printf '  %-10s these bodies have no way in from the index:\n' "UNINDEXED"
    printf '%s' "$missing" | sed 's/^/             /'
    echo "             add a one-line entry to map.md, or the body is unreachable"
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "map is an index"
else
    echo "map has stopped being an index"
    exit 1
fi
