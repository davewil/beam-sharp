#!/usr/bin/env bash
#
# check-surface.sh — every decision that changes what a `.bs` file LOOKS LIKE
# must be traceable from LANGUAGE.md.
#
# WHY THIS EXISTS (2026-08-15)
#
# `check-language.sh` gates LANGUAGE.md against the COMPILER, both ways: an
# untagged block must compile, a `not-yet` block must not. That is a good gate
# and it cannot catch this class of bug, for a structural reason:
#
#   Unbuilt syntax does not compile. So a `not-yet` block holding the CORRECT
#   decided syntax and one holding SUPERSEDED syntax fail identically, and the
#   gate is green either way.
#
# Found the hard way. Ticket 44 changed the conjunction from `&&` to `and`, and
# LANGUAGE.md's refinement block — a `not-yet` block — kept saying `&&` with
# every gate passing. Ticket 42 added relational patterns and LANGUAGE.md did
# not mention them in any form. Nothing was broken; nothing said so.
#
# The window matters because of where this project is going. The compiler is
# source material for a clean-room handoff — a spec an agent fleet implements
# with no access to `wayfinder/`. A `not-yet` block IS spec: it is the part of
# the handoff describing what the implementation must eventually do. So the one
# place the existing gates cannot reach is the place the handoff most depends on.
#
# WHAT IT CHECKS
#
# A decision tagged `syntax` or `patterns` in map.md's Decisions index changes
# the surface, so LANGUAGE.md must cite its ticket by number. Citation rather
# than prose-matching, because citation is mechanical and prose is not — and
# because it makes the trail one grep, which is the same rule the feature files
# already keep with their scenario ids.
#
# CITE IN AN HTML COMMENT, NOT IN THE PROSE:
#
#     <!-- decided by ticket 44, amending ticket 08 -->
#
# LANGUAGE.md's header states it carries no ticket numbers, and that rule is
# load-bearing rather than tidy: the clean-room handoff gives an implementer
# this document and NO ACCESS TO `wayfinder/`, so a ticket number in the running
# text is a pointer to something they do not have. The first cut of this gate
# put seven of them in the prose and contradicted the document it was meant to
# protect. A comment satisfies both — greppable here, invisible there.
#
# It does NOT check that the prose is CORRECT — nothing mechanical can. What it
# guarantees is that no syntax decision can land without somebody opening
# LANGUAGE.md, which is where 44 would have been caught: going to add the
# citation puts you at the stale block.
#
# Semantics-only decisions (compilation target, error model, OTP shape) are out
# of scope by construction: they carry other tags and change no surface.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `CHECK_SURFACE_DIR` exists for the self-test below and holds mutated copies of
# the two files this gate reads, flat. Nothing else sets it; without it the
# paths resolve from the script's own location exactly as before, which is what
# `check-cwd-independence.sh` requires.
if [ -n "${CHECK_SURFACE_DIR:-}" ]; then
    MAP="$CHECK_SURFACE_DIR/map.md"
    LANG_MD="$CHECK_SURFACE_DIR/LANGUAGE.md"
else
    MAP="$HERE/wayfinder/map.md"
    LANG_MD="$HERE/LANGUAGE.md"
fi

# ---------------------------------------------------------------------------
# --self-test
#
# TWO POSITIVE CONTROLS, because this gate can be defeated from either side and
# both happened for real:
#
#   1. LANGUAGE.md loses a citation it used to carry.
#   2. THE MAP GAINS A SURFACE DECISION LANGUAGE.md HAS NEVER MENTIONED. This is
#      the ticket 42 case — relational patterns landed and the document did not
#      mention them in any form — and it is the direction a gate written only
#      against case 1 would miss, because nothing was removed from anywhere.
#
# The negative control is the pair as committed. Both files are copies of the
# real ones: a fixture map with two entries would exercise none of the awk that
# walks the real index.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1 and `pipefail` would
    # hand that status back even when the marker was found.
    control() {
        CHECK_SURFACE_DIR="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }
    fresh() {
        rm -rf "$1"; mkdir -p "$1"
        cp "$HERE/wayfinder/map.md" "$1/map.md"
        cp "$HERE/LANGUAGE.md" "$1/LANGUAGE.md"
    }

    st_fail=0

    # CONTROL 1 — a citation that has fallen out of LANGUAGE.md. `ticket 08` is
    # the guard/interval decision and is cited today; stripping every form of it
    # is what a careless rewrite of that paragraph would do.
    fresh "$CTL/uncited"
    sed -i.bak 's/ticket 08/ticket zero-eight/g; s|issues/08-|issues/xx-|g' \
        "$CTL/uncited/LANGUAGE.md" && rm -f "$CTL/uncited/LANGUAGE.md.bak"
    case "$(control "$CTL/uncited")" in
        *UNCITED*) ;;
        *) echo "SELF-TEST FAILED: a dropped citation was not reported — the gate cannot fire"
           st_fail=1 ;;
    esac

    # CONTROL 2 — a NEW surface decision the document has never mentioned. The
    # ticket number is one the map does not use, so nothing can cite it by
    # accident.
    fresh "$CTL/new"
    awk '
        /^## Decisions so far/ { print; inindex = 1; next }
        inindex && !done && /^- \*\*/ {
            print "- **A surface decision nothing documents** `#97` `syntax`"
            print "  added by this gate self-test"
            done = 1
        }
        { print }
    ' "$CTL/new/map.md" > "$CTL/new/map.tmp" && mv "$CTL/new/map.tmp" "$CTL/new/map.md"
    case "$(control "$CTL/new")" in
        *UNCITED*) ;;
        *) echo "SELF-TEST FAILED: an undocumented new surface decision was not reported —"
           echo "                  the gate only catches removals, which is the weaker half"
           st_fail=1 ;;
    esac

    # NEGATIVE CONTROL — the pair as committed.
    fresh "$CTL/clean"
    if CHECK_SURFACE_DIR="$CTL/clean" "${BASH_SOURCE[0]}" > /dev/null 2>&1; then :; else
        echo "SELF-TEST FAILED: the committed pair was rejected, so this gate would"
        echo "                  fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the dropped citation and the undocumented decision;"
        echo "           accepted the committed pair — the gate discriminates"
        exit 0
    fi
    exit 1
fi

fail=0

echo
echo "surface decisions are traceable from LANGUAGE.md"
echo

for f in "$MAP" "$LANG_MD"; do
    if [ ! -f "$f" ]; then
        printf '  %-12s %s is missing\n' "MISSING" "$f"
        exit 1
    fi
done

# Decisions index only — fog and scope are not decisions and index no surface.
entries=$(awk '/^## Decisions so far/,/^## Not yet specified/' "$MAP" \
    | grep '^- \*\*' \
    | grep -E '`(syntax|patterns)`')

total=0
missing=""

while IFS= read -r line; do
    [ -z "$line" ] && continue
    # `#NN` is the ticket tag. Entries without one (the walking skeleton, which
    # is tagged `compiler/`) name no ticket and cannot be cited.
    num=$(printf '%s' "$line" | grep -o '`#[0-9]\+`' | tr -d '`#')
    [ -z "$num" ] && continue
    total=$((total + 1))

    title=$(printf '%s' "$line" | sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p')

    # Accept `ticket NN` in prose or a markdown link to the issue file. Both are
    # real citations; the link form is what decisions.md uses.
    if grep -Eq "ticket $num\b|issues/$num-" "$LANG_MD"; then
        continue
    fi
    missing="$missing  $num — $title"$'\n'
done <<< "$entries"

if [ -z "$missing" ]; then
    printf '  %-12s all %s surface decisions cited\n' "ok" "$total"
else
    n=$(printf '%s' "$missing" | grep -c .)
    printf '  %-12s %s of %s surface decisions are not cited in LANGUAGE.md:\n' \
        "UNCITED" "$n" "$total"
    printf '%s' "$missing"
    echo
    echo "             a decision tagged \`syntax\` or \`patterns\` changes what a .bs"
    echo "             file looks like, so LANGUAGE.md owes it a mention. Cite it as"
    echo "             \"ticket NN\" where the construct is described."
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "the surface is traceable"
else
    echo "the surface has drifted from the map"
    exit 1
fi
