#!/usr/bin/env bash
#
# EVERY DIAGNOSTIC THE SWITCH SLICE CAN EMIT IS DEFINED IN THE SHIPPING
# REFERENCE, AND DEFINED WHERE A CLEAN-ROOM READER WILL SEE IT.
#
# WHY THIS EXISTS (ENG-248)
# The clean-room audition hands a worker `PACKET.md` — sections 2, 3 and 5 of
# `LANGUAGE.md`, verbatim — and asks it to reimplement the exhaustiveness
# checker. On 2026-08-20 the audition's own report recorded that the compiler
# emits diagnostics on `switch` programs that the specification never names:
# `unbound_variable` and `arg_not_accepted`. A worker could not have derived
# them, because nothing it was given said they existed.
#
# THE COUNT IN THAT REPORT WAS ALSO WRONG, and the way it was wrong is the
# reason this gate reads the suite instead of a list. It said six diagnostics,
# four specified and two not. There are SEVEN. `switch_in_guard` is asserted as
# a BARE ATOM — `{error, _, 'F', switch_in_guard}` — where the other six carry a
# payload — `{error, _, 'Bad', {unbound_variable, w}}`. Any survey that looked
# for `{tag, ...}` saw six and reported a clean number. A hand-maintained list
# in this file would inherit that error and never be re-measured; the suite is
# re-read on every run.
#
# WHAT IT CHECKS
#   1. ENUMERATE the diagnostics the switch slice can emit, from the compiler's
#      own `switch_tests.erl` — the file that already asserts, case by case,
#      what `switch` programs make the compiler say. Both descriptor shapes.
#   2. EVERY ONE IS DEMONSTRATED in `LANGUAGE.md` by a `<!-- diagnoses: tag -->`
#      example, which `check-language.sh` compiles through the public CLI on
#      every run. A demonstration is required rather than a mention, because a
#      mention is what the specification already had: `rebinding` appears in §5
#      by name, and that told a reader nothing about when it fires.
#   3. EVERY DEMONSTRATION IS INSIDE A PACKET SECTION (2, 3 or 5). A rule stated
#      in §7 is in the shipping reference and NOT in the clean-room artifact, so
#      it closes the specification's hole while leaving the audition's open.
#
# WHY NOT ENUMERATE BY COMPILING THE AUDITION'S OWN CASES
# Because that gate is vacuous by construction. `expected/*.tags` holds exactly
# four tags, all four already specified, and the two omissions were deliberately
# kept OUT of `cases/` — the report says so: "a case whose answer the packet
# does not imply measures the specification's holes rather than the worker's".
# A check built on the cases would have passed on the day the defect was filed.
#
# Usage:  compiler/bin/check-switch-diagnostics.sh [--self-test]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
# No `SELF_SH` here, unlike `check-language.sh`: that gate's self-test drives
# controls by RE-INVOKING itself against a fixture document, so it needs its own
# absolute path. This one calls `report` directly, which is the same code the
# main run uses without a second process to locate.

# Both inputs are overridable so --self-test can drive this exact logic over
# fixtures rather than over a second copy of it written to agree with it.
DOC="${SWITCH_DIAG_DOC:-$REPO/LANGUAGE.md}"
SUITE="${SWITCH_DIAG_SUITE:-$REPO/compiler/test/switch_tests.erl}"

# ---------------------------------------------------------------------------
# The switch slice's diagnostic surface, read from the suite.
#
# Two shapes, and the second is why this is a function and not a grep:
#   {error,   _, 'Bad',   {unbound_variable, w}}      payload
#   {error,   _, 'F',     switch_in_guard}            bare atom
#   {warning, _, 'Which', {unreachable_arm, 2}}       payload, warning
# ---------------------------------------------------------------------------
surface() {
    local suite="$1"
    {
        # Payload form: the tag is the atom opening the innermost tuple.
        grep -ohE "\{(error|warning), _[^}]*\{[a-z_][a-z_0-9]*" "$suite" \
            | grep -oE "\{[a-z_][a-z_0-9]*$" | tr -d '{'
        # Bare-atom form: the tag sits directly after the function name.
        grep -ohE "\{(error|warning), _, '[A-Za-z0-9_]+', [a-z_][a-z_0-9]*" "$suite" \
            | sed -E "s/.*, ([a-z_][a-z_0-9]*)\$/\1/"
    } | sort -u
}

# The line a `<!-- diagnoses: tag -->` demonstration sits on, or nothing.
demo_line() {
    local doc="$1" tag="$2"
    # Braced: `$tag[` reads as an array subscript to both bash and shellcheck.
    grep -nE "^<!-- diagnoses:[[:space:]]*${tag}[[:space:]]*-->" "$doc" \
        | head -1 | cut -d: -f1
}

# The packet is built from these three sections and nothing else — the rule
# lives in `build-packet.py`, which calls `section(2)`, `section(3)`, `section(5)`.
in_packet_section() {
    local doc="$1" line="$2"
    local start end n
    for n in 2 3 5; do
        start="$(grep -nE "^## $n\. " "$doc" | head -1 | cut -d: -f1)" || true
        [ -n "$start" ] || continue
        # The section ends at the next `## ` heading, or at end of file.
        end="$(awk -v s="$start" 'NR > s && /^## / { print NR; exit }' "$doc")"
        [ -n "$end" ] || end="$(wc -l < "$doc")"
        if [ "$line" -gt "$start" ] && [ "$line" -lt "$end" ]; then
            printf '%s' "$n"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# The packet's tag vocabulary against the tags the cases actually provoke.
#
# `PACKET.md` tells the worker "these are the ONLY tags you may print" and then
# lists four. `expected/*.tags` is what the reference compiler publishes over
# the same cases, recorded by `oracle.sh`. Nothing held those two together.
#
# Add a case that provokes a fifth diagnostic and the packet instructs the
# worker not to print a tag the marking then requires — an instruction that
# makes the case unpassable, in the artifact rather than in the submission. It
# would read as a worker failure. The reverse is the same defect mirrored: a tag
# listed that no case reaches is prose in the artifact that nothing exercises.
# ---------------------------------------------------------------------------
vocab() {           # tags the packet says a worker may print
    awk '
        /^These are the only tags you may print:/ { grab = 1; next }
        grab && /^[[:space:]]+[a-z_][a-z_0-9]*[[:space:]]*$/ { gsub(/[[:space:]]/, ""); print; next }
        grab && /^\*\*/ { exit }
    ' "$1" | sort -u
}

marked() {          # tags the reference compiler publishes over the cases
    cat "$1"/*.tags 2>/dev/null | tr -s ' \t' '\n' | grep -vE '^$' | sort -u
}

packet_marking() {  # packet_marking <packet> <expected-dir>
    local packet="$1" expdir="$2" t
    while read -r t; do
        [ -n "$t" ] || continue
        printf 'MISMARKED   %s: a case provokes it, and the packet tells the worker not to print it\n' "$t"
    done < <(comm -13 <(vocab "$packet") <(marked "$expdir"))
    while read -r t; do
        [ -n "$t" ] || continue
        printf 'UNEXERCISED %s: the packet lists it and no case provokes it\n' "$t"
    done < <(comm -23 <(vocab "$packet") <(marked "$expdir"))
}

report() {          # report <doc> <suite>  -> prints one line per defect
    local doc="$1" suite="$2"
    local tag line sect
    for tag in $(surface "$suite"); do
        line="$(demo_line "$doc" "$tag")"
        if [ -z "$line" ]; then
            printf 'UNSPECIFIED %s: reachable from a switch, no `<!-- diagnoses: %s -->` example in %s\n' \
                   "$tag" "$tag" "$(basename "$doc")"
            continue
        fi
        if sect="$(in_packet_section "$doc" "$line")"; then
            printf 'ok          %s: demonstrated at %s:%s (section %s)\n' \
                   "$tag" "$(basename "$doc")" "$line" "$sect"
        else
            printf 'OUTSIDE     %s: demonstrated at %s:%s, which is not a packet section (2, 3 or 5)\n' \
                   "$tag" "$(basename "$doc")" "$line"
        fi
    done
}

# ---------------------------------------------------------------------------
# --self-test
#
# THREE WAYS THIS GATE COULD BE GREEN AND WORTHLESS:
#
#   MISSING     a diagnostic gains a test in the suite and nobody documents it.
#               This is the defect the gate was written from, rebuilt.
#   NAME-ONLY   the tag is MENTIONED in the reference and never demonstrated.
#               This is the plausible-but-wrong implementation — `grep -q
#               unbound_variable LANGUAGE.md` — and it is what the document
#               already looked like for `rebinding`, which is named in §5 and
#               was still not a rule anyone could apply. A gate satisfied by a
#               mention would have passed on the day the defect was filed.
#   OUTSIDE     the rule is written somewhere the clean-room worker never
#               receives. The specification is then complete and the artifact
#               is not, which is precisely ENG-248's complaint.
#
# Plus the negative control: the repository as committed must pass, or the gate
# fails every clean tree and gets deleted.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT
    st_fail=0

    expect() {      # expect <marker> <doc> <suite> <what was built>
        local out
        out="$(report "$2" "$3" || true)"
        case "$out" in
            *"$1"*) ;;
            *) echo "SELF-TEST FAILED: $4 was not reported — the $1 check cannot fire"
               st_fail=1 ;;
        esac
    }

    # CONTROL 1 — a diagnostic the suite exercises and the reference never shows.
    cp "$SUITE" "$CTL/extra_tests.erl"
    printf "\nan_invented_diagnostic_test() ->\n    ?assertMatch([{error, _, 'Z', {no_such_diagnostic, x}}], errors(Src)).\n" \
        >> "$CTL/extra_tests.erl"
    expect "UNSPECIFIED" "$DOC" "$CTL/extra_tests.erl" \
           "a diagnostic asserted in the suite with no example in the reference"

    # CONTROL 2 — the tag named in prose, with no demonstration.
    #
    # The whole document minus its `diagnoses:` preambles. Every tag is still
    # mentioned by name in the prose that surrounded each example, so a gate
    # that greps for names sees a complete specification here.
    grep -vE '^<!-- diagnoses:' "$DOC" > "$CTL/nameonly.md"
    expect "UNSPECIFIED" "$CTL/nameonly.md" "$SUITE" \
           "a reference that names every tag and demonstrates none"

    # CONTROL 3 — a demonstration outside the sections the packet ships.
    #
    # Built by moving one example into section 7, which is in the reference and
    # is not in the artifact.
    awk '
        /^<!-- diagnoses:[ \t]*unbound_variable/ { skip = 3; next }
        skip > 0 { skip--; next }
        { print }
    ' "$DOC" > "$CTL/outside.md"
    printf '\n<!-- diagnoses: unbound_variable -->\n' >> "$CTL/outside.md"
    expect "OUTSIDE" "$CTL/outside.md" "$SUITE" \
           "a rule stated outside the sections the clean-room worker receives"

    # CONTROL 4 — a packet that is not what the generator would write today.
    #
    # Built in a throwaway tree rather than by touching the real `PACKET.md`:
    # `build-packet.py` finds the repository from its own location, so a copy of
    # it beside a copy of `LANGUAGE.md` is a complete, disposable repository as
    # far as it is concerned. The defect is then the real one — THE SOURCE MOVED
    # AND NOBODY REBUILT — rather than a mangled artifact, which is a different
    # failure and the easier one to catch.
    PKG="$CTL/pkg/handoff/audition-switch"
    mkdir -p "$PKG"
    cp "$REPO/LANGUAGE.md" "$CTL/pkg/LANGUAGE.md"
    cp "$REPO/handoff/audition-switch/build-packet.py" "$PKG/build-packet.py"
    python3 "$PKG/build-packet.py" > /dev/null

    # Positive half first: a packet just built must be accepted, or `--check`
    # is a check that always fails and proves nothing about staleness.
    if ! python3 "$PKG/build-packet.py" --check > /dev/null 2>&1; then
        echo "SELF-TEST FAILED: a freshly built packet was reported stale, so the"
        echo "                  freshness check fires on everything and means nothing"
        st_fail=1
    fi

    # Now move the specification underneath it, inside a section the packet ships.
    awk '
        !done && /^## 5\. / { print; print ""; print "A sentence added to section 5 after the packet was built."; done = 1; next }
        { print }
    ' "$REPO/LANGUAGE.md" > "$CTL/pkg/LANGUAGE.md.new"
    mv "$CTL/pkg/LANGUAGE.md.new" "$CTL/pkg/LANGUAGE.md"

    if python3 "$PKG/build-packet.py" --check > /dev/null 2>&1; then
        echo "SELF-TEST FAILED: section 5 changed and the packet built from it was still"
        echo "                  called current — the STALE check cannot fire"
        st_fail=1
    fi

    # CONTROL 5 — a case provoking a tag the packet forbids.
    #
    # The instruction and the marking disagree, and the worker is the one that
    # looks wrong. Built by recording an extra expectation, which is exactly
    # what adding a case does: `oracle.sh` writes one `.tags` file per case.
    mkdir -p "$CTL/expected"
    cp "$REPO/handoff/audition-switch/expected/"*.tags "$CTL/expected/"
    printf 'unbound_variable\n' > "$CTL/expected/c99-invented.tags"
    case "$(packet_marking "$REPO/handoff/audition-switch/PACKET.md" "$CTL/expected" || true)" in
        *MISMARKED*) ;;
        *) echo "SELF-TEST FAILED: a case provoking a tag the packet forbids was not"
           echo "                  reported — the MISMARKED check cannot fire"
           st_fail=1 ;;
    esac

    # NEGATIVE CONTROL — the repository as committed.
    if [ -n "$(packet_marking "$REPO/handoff/audition-switch/PACKET.md" \
                              "$REPO/handoff/audition-switch/expected")" ]; then
        echo "SELF-TEST FAILED: the committed packet and expectations were reported as"
        echo "                  disagreeing, so this check fires on a correct tree"
        st_fail=1
    fi
    if report "$DOC" "$SUITE" | grep -qE '^(UNSPECIFIED|OUTSIDE)'; then
        echo "SELF-TEST FAILED: the repository as committed was rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the undocumented diagnostic, the reference that names"
        echo "           every tag without demonstrating one, the rule written outside"
        echo "           the packet's sections, the packet left unbuilt after its source"
        echo "           moved, and a case provoking a tag the packet forbids; accepted a"
        echo "           freshly built packet, the committed vocabulary, and the tree as"
        echo "           committed"
        exit 0
    fi
    exit 1
fi

OUT="$(report "$DOC" "$SUITE")"
printf '%s\n' "$OUT"
echo
printf '%s diagnostics reachable from a switch\n' "$(surface "$SUITE" | wc -l | tr -d ' ')"

rc=0
if printf '%s\n' "$OUT" | grep -qE '^(UNSPECIFIED|OUTSIDE)'; then
    echo
    echo "Every diagnostic a switch program can provoke must be demonstrated in a"
    echo "packet section, by an example \`check-language.sh\` compiles. See ENG-248."
    rc=1
fi

# CHECK 4 — the packet the worker receives is the specification as it stands.
#
# The checks above locate each rule in a packet SECTION of `LANGUAGE.md`.
# `PACKET.md` is a BUILT copy of those sections, and nothing verified it had
# been rebuilt: an edit to §5 left the artifact describing the older language
# while every check here stayed green. Locating a rule in a section the worker
# never actually receives is not a completed claim, so the freshness of the file
# belongs to this gate rather than to a reader's memory.
#
# Skipped rather than failed when the document is a self-test fixture: the
# packet is built from the real `LANGUAGE.md` and cannot be current with a
# temporary copy that has had a control block appended to it.
if [ "$DOC" = "$REPO/LANGUAGE.md" ]; then
    if ! python3 "$REPO/handoff/audition-switch/build-packet.py" --check; then
        rc=1
    fi

    # CHECK 5 — the packet's vocabulary and the recorded expectations agree.
    MARKING="$(packet_marking "$REPO/handoff/audition-switch/PACKET.md" \
                              "$REPO/handoff/audition-switch/expected")"
    if [ -n "$MARKING" ]; then
        echo
        printf '%s\n' "$MARKING"
        echo
        echo "The packet's tag list and \`expected/\` are one contract: a tag the marking"
        echo "requires and the packet forbids makes a case unpassable from inside the"
        echo "artifact. Update the vocabulary in build-packet.py and regenerate."
        rc=1
    else
        printf 'the packet lists exactly the %s tags the cases provoke\n' \
               "$(vocab "$REPO/handoff/audition-switch/PACKET.md" | wc -l | tr -d ' ')"
    fi
fi

exit "$rc"
