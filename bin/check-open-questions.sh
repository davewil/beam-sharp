#!/usr/bin/env bash
#
# check-open-questions.sh — an open question in the spec must be tracked, or
# nothing schedules it.
#
# WHY THIS EXISTS (2026-08-31)
#
# `LANGUAGE.md` §19 is headed "Open questions" and it is accurate: on the day
# this gate was written it named six, and every one of them was a real gap in
# the design. Five of the six had NO LINEAR ISSUE ANYWHERE IN TEAM ENG.
#
# That is not a filing complaint. Linear owns state in this project — CLAUDE.md
# says so, and the reason given is that Linear renders the frontier visually
# where a markdown line cannot. A question with no issue therefore has nowhere
# to hold any state at all: no owner, no age, no blocking relation, and no way
# to appear in the query that decides what happens next. It is invisible to the
# only mechanism that schedules work.
#
# THE COST IS MEASURED, NOT FEARED. Five questions that surfaced late, and what
# found each one:
#
#   ticket 09's recursive types   decided 08-12, surfaced 08-26 (14 days) when
#                                 exemplar 25e hit the wall. FOUR files had
#                                 written "when it lands"; none was a ticket.
#   ticket 65's reserved names    scoped 08-15, raised 08-25 (10 days) only
#                                 because ticket 48's Q9 escaped its own scope.
#   ticket 55's record binder     owed 9 days by the exemplar README and by
#                                 LANGUAGE.md independently; neither raised it.
#   F29's residual printer        decided 08-15, filed as a NEW discovery three
#                                 separate times before it became a feature.
#   ENG-270's module lockout      a program with no legal spelling, found by a
#                                 prototype run for a different ticket.
#
# Every one was found by something WALKING INTO IT. This repository has 29
# gates and every other one asks the same question — does the code match the
# document? Not one asks whether an undecided question has an owner, because
# undecided work has no age: a question opened sixteen days ago is
# indistinguishable from one opened last night.
#
# WHAT IT CHECKS
#
# Every bullet under `## 19. Open questions` carries a tracking comment naming
# a Linear issue:
#
#     - **Laziness** and `stream<T>` — deferred, not refused. <!-- tracked by ENG-283 -->
#
# IN A COMMENT, NOT IN THE PROSE, and that is the same rule `check-surface.sh`
# already enforces for ticket citations. `LANGUAGE.md`'s header states it
# carries no tracker references, and the rule is load-bearing rather than tidy:
# the clean-room handoff gives an implementer this document and no access to
# Linear, so an issue id in the running text points at something they do not
# have. A comment satisfies both — greppable here, invisible in the rendered
# document — and ticket citations have shipped that way since 2026-08-15.
#
# DO NOT REACH FOR `build-packet.py` AS THE REASON. The first version of this
# header said the id never reaches a worker because that script "strips every
# comment except `check:` blocks", and that is not what it does to a citation of
# this shape: the substitution is `^<!--(?!\s*check:).*?-->\n`, ANCHORED AT LINE
# START, and its own comment says why — "so an inline comment inside an example
# is left alone". A citation sitting at the end of a bullet is exactly that, and
# it would survive.
#
# What actually holds is narrower and worth stating: the audition packet is
# assembled from LANGUAGE.md sections 2, 3 and 5, and section 19 is not among
# them, so it is never assembled in the first place. The claim was true for the
# wrong reason, which is the kind of true that stops being true when somebody
# adds a section to the packet.
#
# WHAT IT DOES NOT CHECK, deliberately: whether the issue is OPEN. That would
# make this gate depend on the network, and a gate that cannot run offline runs
# in nobody's pre-commit. A question resolved in Linear and still listed here
# is caught by the other direction — §19 is prose that a resolving session must
# edit, and `check-status-claims.sh` already fails a document that claims
# something the compiler contradicts.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `CHECK_OPEN_QUESTIONS_DIR` exists for the self-test below and holds a mutated
# copy of the one file this gate reads. Nothing else sets it; without it the
# path resolves from the script's own location, which is what
# `check-cwd-independence.sh` requires.
if [ -n "${CHECK_OPEN_QUESTIONS_DIR:-}" ]; then
    LANG_MD="$CHECK_OPEN_QUESTIONS_DIR/LANGUAGE.md"
else
    LANG_MD="$HERE/LANGUAGE.md"
fi

# Walk §19 and print one line per bullet: the marker, then the bullet's text.
# A bullet is its `- ` line plus any indented continuation lines, so the comment
# may sit at the end of a bullet that wraps. Both the section bound and the
# bullet grouping are in awk rather than grep because a grep for the comment
# would pass a file whose §19 had been deleted entirely.
bullets() {
    awk '
        /^## 19\. Open questions/ { in19 = 1; next }
        in19 && /^## /            { flush(); in19 = 0 }
        !in19                     { next }
        /^---[[:space:]]*$/       { flush(); next }
        /^- /                     { flush(); cur = $0; next }
        /^[[:space:]]+[^[:space:]]/ { if (cur != "") cur = cur " " $0; next }
        { flush() }
        END { flush() }
        function flush() {
            if (cur == "") return
            if (cur ~ /<!--[[:space:]]*tracked by ENG-[0-9]+[[:space:]]*-->/)
                printf "TRACKED %s\n", cur
            else
                printf "UNTRACKED %s\n", cur
            cur = ""
        }
    ' "$1"
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR CONTROLS. The first two are the two directions this gate can be defeated
# from, the third is the cry-wolf control that a lookup-table gate would fail,
# and the fourth is the one that keeps the citation from being decorative.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1, and `pipefail`
    # would hand that status back even when the marker was found.
    #
    # THE CONTROLS ASSERT ON THE PRINTED REPORT, NOT ON THE INTERNAL MARKER.
    # The first cut of this self-test matched `*UNTRACKED*`, which `bullets`
    # emits and the report then STRIPS on its way to the reader — so all three
    # positive controls failed while the gate itself was working perfectly. A
    # self-test that reads a channel its own gate does not publish measures
    # nothing, and it would have been just as silent had it passed.
    control() {
        CHECK_OPEN_QUESTIONS_DIR="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }
    fresh() {
        rm -rf "$1"; mkdir -p "$1"
        cp "$HERE/LANGUAGE.md" "$1/LANGUAGE.md"
    }

    st_fail=0

    # CONTROL 1 — a citation falls out. This is what a careless rewrite of one
    # bullet does, and it is the state the whole section was in until today.
    fresh "$CTL/dropped"
    sed -i.bak 's|<!-- tracked by ENG-284 -->||' "$CTL/dropped/LANGUAGE.md"
    rm -f "$CTL/dropped/LANGUAGE.md.bak"
    case "$(control "$CTL/dropped")" in
        *"names no issue"*Bootstrapping*) ;;
        *) echo "SELF-TEST FAILED: a dropped citation was not reported — the gate cannot fire"
           st_fail=1 ;;
    esac

    # CONTROL 2 — A NEW QUESTION IS ADDED AND CITES NOTHING. This is the
    # direction that matters and the one a gate written only against control 1
    # would miss: nothing was removed from anywhere, and the section grew by a
    # line that no query will ever see.
    fresh "$CTL/added"
    awk '
        /^## 19\. Open questions/ { print; print ""; print "- **A brand new question** nobody has filed."; next }
        { print }
    ' "$CTL/added/LANGUAGE.md" > "$CTL/added/LANGUAGE.new"
    mv "$CTL/added/LANGUAGE.new" "$CTL/added/LANGUAGE.md"
    case "$(control "$CTL/added")" in
        *"names no issue"*"brand new question"*) ;;
        *) echo "SELF-TEST FAILED: a new uncited question was not reported"
           st_fail=1 ;;
    esac

    # CONTROL 3 — THE CRY-WOLF CONTROL. A gate that fires on everything passes
    # the two above and is worthless, so the file as committed must be green
    # standing beside them.
    fresh "$CTL/clean"
    if ! CHECK_OPEN_QUESTIONS_DIR="$CTL/clean" "${BASH_SOURCE[0]}" >/dev/null 2>&1; then
        echo "SELF-TEST FAILED: the committed LANGUAGE.md is red — the gate fires on the correct form"
        st_fail=1
    fi

    # CONTROL 4 — A COMMENT THAT IS NOT AN ISSUE. `<!-- tracked later -->` reads
    # like provenance and holds no state, which is precisely the thing this gate
    # exists to refuse; without this control the marker could be any comment at
    # all and the section would drift back one word at a time.
    fresh "$CTL/vague"
    sed -i.bak 's|<!-- tracked by ENG-282 -->|<!-- tracked later -->|' "$CTL/vague/LANGUAGE.md"
    rm -f "$CTL/vague/LANGUAGE.md.bak"
    case "$(control "$CTL/vague")" in
        *"names no issue"*'`cond`'*) ;;
        *) echo "SELF-TEST FAILED: a comment naming no issue was accepted as a citation"
           st_fail=1 ;;
    esac

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test ok  4 controls: dropped citation, new uncited question, cry-wolf, vague comment"
    fi
    exit "$st_fail"
fi

# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------
if [ ! -f "$LANG_MD" ]; then
    echo "check-open-questions: $LANG_MD does not exist"
    exit 1
fi

found="$(bullets "$LANG_MD")"

# THE FLOOR. A gate that enumerates nothing passes everything, and this one is
# one deleted heading away from doing exactly that — `awk` finds no §19, prints
# nothing, and every bullet is vacuously tracked. §19 has never held fewer than
# six entries, so the floor is set where deleting the section is red rather than
# silent.
count="$(printf '%s\n' "$found" | grep -c '^TRACKED\|^UNTRACKED' || true)"
if [ "$count" -lt 1 ]; then
    echo "check-open-questions: no bullets found under '## 19. Open questions'"
    echo "  either the section was renamed or it was deleted; both are red here."
    exit 1
fi

untracked="$(printf '%s\n' "$found" | grep '^UNTRACKED' || true)"
if [ -n "$untracked" ]; then
    echo "check-open-questions: an open question in LANGUAGE.md section 19 names no issue."
    echo
    printf '%s\n' "$untracked" | sed 's/^UNTRACKED /  /'
    echo
    echo "  Linear owns state in this project, so a question with no issue has nowhere to"
    echo "  hold an owner, an age or a blocking relation — and the frontier query cannot"
    echo "  see it. Raise it, then cite it here in a comment:"
    echo
    echo "      - **Laziness** and \`stream<T>\` — deferred, not refused. <!-- tracked by ENG-283 -->"
    echo
    echo "  The comment, not the prose: the clean-room handoff ships this document without"
    echo "  Linear, and build-packet.py strips every comment except check: blocks."
    exit 1
fi

echo "  ok         $count open questions in LANGUAGE.md section 19, each naming an issue"
