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
MAP="$HERE/wayfinder/map.md"
LANG_MD="$HERE/LANGUAGE.md"

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
