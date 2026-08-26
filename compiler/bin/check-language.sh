#!/usr/bin/env bash
#
# Compile every beam-sharp code block in LANGUAGE.md and check it against what
# the block claims to be.
#
# WHY THIS EXISTS
# On 2026-08-14 David read LANGUAGE.md, typed what it showed, and hit two
# things the compiler had never had: `Area(Circle c)` as a dispatch form, and
# `Order o = Order { ... }` as a binding. Both had been true of the *decisions*
# and never of the *language*. The reference is written from the tickets, so it
# drifts in exactly the places nobody runs — which is every place, because
# nothing ran it.
#
# THE CHECK IS BIDIRECTIONAL, AND THAT IS THE POINT
# A block is either shipped surface or planned surface, and BOTH claims are
# checked:
#
#   ```csharp            must compile. If it stops, the reference is lying.
#   ```csharp not-yet    must NOT compile. If it STARTS compiling, somebody
#                        built the feature and left the doc calling it planned.
#
# So neither tag can rot silently. The second half is the one that pays: when a
# feature lands, CI names the paragraphs that now need promoting, instead of
# waiting for a reader to trip over them.
#
#   ```csharp illustrative   skipped, and counted in the summary so the number
#                            of unchecked blocks stays visible rather than
#                            drifting upward unnoticed.
#
# THE THIRD CLAIM: AN EXAMPLE THAT DEMONSTRATES A DIAGNOSTIC
#
#   <!-- diagnoses: unbound_variable -->
#   ```csharp
#   ...
#
# The block must produce EXACTLY that one diagnostic tag, published on
# `--diagnostics term` — the same boundary `oracle.sh` records the audition's
# expectations from, so a rule stated in the reference is verified through the
# compiler's public output rather than against a hand-written belief about it.
#
# WHY THIS WAS NEEDED (ENG-248, 2026-08-27). Until this existed the reference
# could not state a rule about a REJECTED program and have the statement
# checked. The three claims above cover "compiles", "does not compile yet" and
# "not checked", and an example of a diagnostic fits none of them: a bare fence
# fails, `not-yet` passes while asserting the falsehood that shipped behaviour
# is planned, and `illustrative` is the ungated prose that finding 9 of the
# switch audition identified as the place documentation rots. Three of the
# switch slice's seven diagnostics — `unbound_variable`, `arg_not_accepted` and
# `switch_in_guard` — were undocumented for exactly this reason.
#
# NOT `rejects:`. `unreachable_arm` is a WARNING, so a block demonstrating it
# still compiles. The claim is about the diagnostic the example provokes, not
# about the exit status, and the word has to survive both kinds.
#
# EXACTLY ONE TAG, NOT "AT LEAST". A superset would let a careless example
# satisfy the gate while provoking two unrelated errors on the way to the one
# being illustrated, and the reader would have no way to tell which of them the
# surrounding prose is about.
#
# WHY A COMMENT AND NOT A FENCE TAG. `build-packet.py` copies sections 2, 3 and
# 5 of this file VERBATIM into the audition packet, stripping only
# `<!-- decided by ... -->`. A ```` ```csharp diagnoses:unbound_variable ````
# fence would therefore reach the worker with the answer printed on the example
# — the exact leak that generator's own comment exists to prevent ("a candidate
# read the answer off the mark sheet instead of deriving it"). An HTML comment
# is invisible in rendered Markdown and, unlike the `check:` preambles, carries
# nothing the example needs in order to compile.
#
# GIVING A BLOCK ITS CONTEXT
# Most blocks are excerpts and do not declare the types they mention. An HTML
# comment immediately before the fence supplies the missing declarations. It is
# invisible in rendered Markdown, so the reader still sees a clean example:
#
#   <!-- check:
#   record Order { Id: int, Total: int }
#   -->
#   ```csharp
#   int Squared(Order o)
#   ...
#
# A `module` line is prepended when the block has none, so an excerpt does not
# have to carry one just to be checkable.
#
# Usage:  compiler/bin/check-language.sh [-v]
#           -v  print the source and the compiler's output for every failure

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
# `CHECK_LANGUAGE_DOC` exists for the self-test below, which points this gate at
# copies of LANGUAGE.md carrying one added block each. Nothing else sets it.
DOC="${CHECK_LANGUAGE_DOC:-$REPO/LANGUAGE.md}"
BSC="$HERE/_build/default/bin/bsc"

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

[ -f "$DOC" ] || { echo "no LANGUAGE.md at $DOC" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --self-test
#
# THE BIDIRECTIONAL CLAIM NEEDS A CONTROL IN BOTH DIRECTIONS, and only one of
# them is obvious.
#
#   BROKEN   — an untagged block that does not compile. The control is the exact
#              defect this gate was built from: `Order o = Order { ... }`, which
#              David typed out of the reference on 2026-08-14 and which the
#              language has never had.
#   PROMOTED — a `not-yet` block that DOES compile. This is the half that pays,
#              and the half a self-test would skip if it only thought about
#              things being broken: when a feature lands, this is what names the
#              paragraphs still calling it planned.
#   BAD TAG  — a fence tag the gate does not know, which must be an error rather
#              than a silent skip.
#
# The negative control is LANGUAGE.md as committed. Each control is that file
# plus one block, so nothing else about the document changes underneath them.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    if [ ! -x "$BSC" ]; then
        echo "SELF-TEST CANNOT RUN: no escript at $BSC"
        echo "  rebar3 escriptize   (in compiler/, as ci.yml does before this step)"
        exit 1
    fi

    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1, and `pipefail`
    # would report that status even when the marker was found.
    control() {
        CHECK_LANGUAGE_DOC="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }

    st_fail=0
    expect() {   # expect <marker> <file> <what the control built>
        case "$(control "$2")" in
            *"$1"*) ;;
            *) echo "SELF-TEST FAILED: $3 was not reported — the $1 check cannot fire"
               st_fail=1 ;;
        esac
    }

    # CONTROL 1 — the reference showing something the language has never had.
    cp "$REPO/LANGUAGE.md" "$CTL/broken.md"
    {
        printf '\n```csharp\n'
        printf 'record Order { Id: int, Total: int }\n\n'
        printf 'public Order New()\n'
        printf 'New() ->\n'
        printf '    Order o = Order { Id = 1, Total = 0 }\n'
        printf '    o\n'
        printf '```\n'
    } >> "$CTL/broken.md"
    expect "BROKEN" "$CTL/broken.md" "an untagged block that does not compile"

    # CONTROL 2 — a block still marked planned that the compiler now accepts.
    cp "$REPO/LANGUAGE.md" "$CTL/promoted.md"
    {
        printf '\n```csharp not-yet\n'
        printf 'public int Twice(int n)\n'
        printf 'Twice(n) -> n * 2\n'
        printf '```\n'
    } >> "$CTL/promoted.md"
    expect "PROMOTED" "$CTL/promoted.md" "a shipped construct still tagged not-yet"

    # CONTROL 3 — a tag nothing knows. It must be an error, not a quiet skip.
    cp "$REPO/LANGUAGE.md" "$CTL/badtag.md"
    {
        printf '\n```csharp probably\n'
        printf 'public int Twice(int n)\n'
        printf 'Twice(n) -> n * 2\n'
        printf '```\n'
    } >> "$CTL/badtag.md"
    expect "BAD TAG" "$CTL/badtag.md" "an unknown fence tag"

    # ------------------------------------------------------------------
    # CONTROLS 4-7 — the `diagnoses:` claim (ENG-248).
    #
    # A CLAIM ABOUT A DIAGNOSTIC NEEDS THREE CONTROLS, and only the first is
    # obvious. All three are ways for this check to be worthless while green:
    #
    #   SILENT    the example provokes NOTHING. A gate that only asked "did it
    #             fail?" would be satisfied by `not-yet` and would never notice
    #             that the paragraph's example stopped illustrating anything.
    #   WRONG     the example provokes a DIFFERENT diagnostic. This is the
    #             control that separates `diagnoses:` from `not-yet` — both
    #             blocks fail to compile, and only one of them is right. Without
    #             it the tag name is decoration.
    #   SUPERSET  the example provokes the claimed diagnostic AND others. The
    #             plausible-but-wrong implementation is `grep -q`, which passes
    #             this. A reader cannot tell which of three errors the prose is
    #             about, so the example has to be minimal to be an example.
    #
    # And the fourth is the ordinary one: two claims about one block.
    # ------------------------------------------------------------------

    # A well-formed switch, claimed to diagnose something.
    cp "$REPO/LANGUAGE.md" "$CTL/silent.md"
    {
        printf '\n<!-- diagnoses: unbound_variable -->\n'
        printf '```csharp\n'
        printf 'module DiagSilent\n'
        printf 'public atom Describe(atom s)\n'
        printf 'Describe(s) -> s switch {\n'
        printf '    :placed => :new,\n'
        printf '    _       => :unknown\n'
        printf '}\n'
        printf '```\n'
    } >> "$CTL/silent.md"
    expect "WRONG DIAG" "$CTL/silent.md" "an example that provokes no diagnostic at all"

    # The unbound-variable program, claimed to be about rebinding.
    cp "$REPO/LANGUAGE.md" "$CTL/wrongtag.md"
    {
        printf '\n<!-- diagnoses: rebinding -->\n'
        printf '```csharp\n'
        printf 'module DiagWrong\n'
        printf 'public term Bad(term e)\n'
        printf 'Bad(e) -> e switch {\n'
        printf '    (:ok, v) => w,\n'
        printf '    (:no, w) => w\n'
        printf '}\n'
        printf '```\n'
    } >> "$CTL/wrongtag.md"
    expect "WRONG DIAG" "$CTL/wrongtag.md" "an example that provokes a different diagnostic"

    # The claimed diagnostic, plus an unrelated second one.
    cp "$REPO/LANGUAGE.md" "$CTL/superset.md"
    {
        printf '\n<!-- diagnoses: unbound_variable -->\n'
        printf '```csharp\n'
        printf 'module DiagSuperset\n'
        printf 'public term Bad(term e)\n'
        printf 'Bad(e) -> e switch {\n'
        printf '    (:ok, v) => w,\n'
        printf '    (:no, w) => w\n'
        printf '}\n'
        printf '\n'
        printf 'public atom Gappy(bool b)\n'
        printf 'Gappy(b) -> b switch {\n'
        printf '    true => :yes\n'
        printf '}\n'
        printf '```\n'
    } >> "$CTL/superset.md"
    expect "WRONG DIAG" "$CTL/superset.md" "an example carrying a second, unrelated diagnostic"

    # A fence tag and a preamble, disagreeing about one block.
    cp "$REPO/LANGUAGE.md" "$CTL/twoclaims.md"
    {
        printf '\n<!-- diagnoses: unbound_variable -->\n'
        printf '```csharp not-yet\n'
        printf 'module DiagTwoClaims\n'
        printf 'public int Twice(int n)\n'
        printf 'Twice(n) -> n * 2\n'
        printf '```\n'
    } >> "$CTL/twoclaims.md"
    expect "BAD TAG" "$CTL/twoclaims.md" "a block carrying two different claims"

    # POSITIVE CONTROL — a correct `diagnoses:` block must be ACCEPTED.
    #
    # Without this the three above are satisfied by a check that rejects every
    # `diagnoses:` block it sees, which is the cry-wolf stub: it fires on the
    # defect and on the correct form alike, and is worthless in the same way a
    # check that never fires is. CLAUDE.md's rule, both halves.
    cp "$REPO/LANGUAGE.md" "$CTL/good.md"
    {
        printf '\n<!-- diagnoses: unbound_variable -->\n'
        printf '```csharp\n'
        printf 'module DiagGood\n'
        printf 'public term Bad(term e)\n'
        printf 'Bad(e) -> e switch {\n'
        printf '    (:ok, v) => w,\n'
        printf '    (:no, w) => w\n'
        printf '}\n'
        printf '```\n'
    } >> "$CTL/good.md"
    if CHECK_LANGUAGE_DOC="$CTL/good.md" "${BASH_SOURCE[0]}" > /dev/null 2>&1
    then :; else
        echo "SELF-TEST FAILED: a correct \`diagnoses:\` example was rejected, so this"
        echo "                  check fires on the defect and the correct form alike"
        st_fail=1
    fi

    # NEGATIVE CONTROL — the reference as committed.
    if CHECK_LANGUAGE_DOC="$REPO/LANGUAGE.md" "${BASH_SOURCE[0]}" > /dev/null 2>&1
    then :; else
        echo "SELF-TEST FAILED: the reference as committed was rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the uncompilable block, the construct that has since"
        echo "           shipped, the unknown tag, and four ways a \`diagnoses:\` example"
        echo "           can be wrong — silent, mislabelled, carrying a second diagnostic,"
        echo "           and claimed twice; accepted a correct one and the committed"
        echo "           reference — the gate discriminates in both directions"
        exit 0
    fi
    exit 1
fi

if [ ! -x "$BSC" ]; then
    echo "building bsc..." >&2
    (cd "$HERE" && rebar3 escriptize >/dev/null)
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- split the document into one .bs per block, plus a .tag and a .line -------
#
# Written in awk rather than a Markdown library because the shape being parsed
# is three lines of grammar and the alternative is a dependency the compiler
# does not otherwise have.
awk -v out="$WORK" '
function flush_preamble() { pre = ""; dg = ""; }
/^<!-- check:/ { inpre = 1; pre = ""; next }
inpre && /^-->/ { inpre = 0; next }
inpre { pre = pre $0 "\n"; next }

# `<!-- diagnoses: tag -->`. Reset by flush_preamble along with the `check:`
# block, so it binds to the fence it sits immediately above and cannot drift
# down the document to claim a block written later.
/^<!-- diagnoses:/ {
    dg = $0
    sub(/^<!-- diagnoses:[ \t]*/, "", dg)
    sub(/[ \t]*-->.*$/, "", dg)
    next
}

/^```csharp/ {
    n++
    tag = $0
    sub(/^```csharp[ \t]*/, "", tag)
    # A fence tag and a `diagnoses:` preamble make two different claims about
    # one block. Rather than pick a winner, emit something no case matches so
    # it surfaces as BAD TAG.
    if (tag != "" && dg != "") tag = "both:" tag ":" dg
    else if (tag == "" && dg != "") tag = "diagnoses:" dg
    else if (tag == "") tag = "must-compile"
    print tag > (out "/" n ".tag")
    print NR + 1 > (out "/" n ".line")
    body = ""
    inblock = 1
    next
}
inblock && /^```/ {
    inblock = 0
    src = pre body
    if (src !~ /(^|\n)module /) src = "module Doc" n "\n\n" src
    printf "%s", src > (out "/" n ".bs")
    flush_preamble()
    next
}
inblock { body = body $0 "\n"; next }
{ if (!inpre) flush_preamble() }
END { print n > (out "/count") }
' "$DOC"

COUNT="$(cat "$WORK/count")"

pass=0; fail=0; skipped=0
FAILURES=""

for i in $(seq 1 "$COUNT"); do
    tag="$(cat "$WORK/$i.tag")"
    line="$(cat "$WORK/$i.line")"

    if [ "$tag" = "illustrative" ]; then
        skipped=$((skipped + 1))
        printf '  %-12s LANGUAGE.md:%s\n' "skipped" "$line"
        continue
    fi

    out="$WORK/out$i"
    mkdir -p "$out"

    # F15 — EACH BLOCK GETS ITS OWN MODULE DIRECTORY, named for what it declares.
    #
    # Every block used to be written straight into `$WORK` as `<n>.bs`, which is
    # now ONE directory holding twenty-four `module` lines — one module that
    # cannot decide on its name, so every block failed at once. Ticket 41 §5's
    # path check then wants the directory to match the declaration, and the awk
    # above guarantees there is one to match: a block with no `module` line gets
    # `module Doc<n>` synthesised.
    mod="$(sed -n 's/^module \([A-Za-z0-9_.]*\).*/\1/p' "$WORK/$i.bs" | head -1)"
    src="$WORK/b$i/$(printf '%s' "$mod" | tr '.' '/')/$i.bs"
    mkdir -p "$(dirname "$src")"
    cp "$WORK/$i.bs" "$src"

    # A `diagnoses:` block is judged on WHAT THE COMPILER PUBLISHED, not on
    # whether it compiled. `unreachable_arm` is a warning, so its example
    # compiles and still carries the diagnostic the prose is about; an exit
    # status cannot tell those two situations apart.
    #
    # `--diagnostics term` and this extraction are `oracle.sh`'s, deliberately:
    # the audition's expectations and the reference's examples then agree
    # because they are read off the same public output, rather than because two
    # authors believed the same thing on two different days.
    case "$tag" in
    diagnoses:*)
        want="${tag#diagnoses:}"
        # THROUGH A FILE, NOT A PIPELINE INSIDE `$( )`. The obvious spelling is
        # `got="$({ "$BSC" ... || true; } | sed ...)"`, and bash 3.2 — which is
        # what macOS ships and what this repo is developed on — cannot parse a
        # brace group inside command substitution across a line continuation.
        # CI's bash 5 parses it, so the construct is green there and a syntax
        # error here. Worse, bash parses incrementally: `--self-test` returns
        # before reaching this line, so the parent looked healthy while every
        # child died into `2>&1` and all seven controls reported only that they
        # "cannot fire".
        #
        # `|| true` — a block that demonstrates an ERROR exits non-zero, which
        # is the normal case here and must not abort the run under `pipefail`.
        "$BSC" --diagnostics term --src-root "$WORK/b$i" -o "$out" "$src" \
            > "$WORK/$i.term" 2>/dev/null || true
        got="$(sed -n 's/.*tag => \([a-z_][a-z_0-9]*\).*/\1/p' "$WORK/$i.term" | sort -u | tr '\n' ' ')"
        got="${got% }"
        if [ "$got" = "$want" ]; then
            pass=$((pass + 1))
            printf '  %-12s LANGUAGE.md:%s\n' "ok ($tag)" "$line"
        else
            fail=$((fail + 1))
            printf '  %-12s LANGUAGE.md:%s  the example claims `%s`, the compiler published `%s`\n' \
                   "WRONG DIAG" "$line" "$want" "${got:-nothing}"
            FAILURES="$FAILURES $i"
        fi
        continue
        ;;
    esac

    if "$BSC" --src-root "$WORK/b$i" -o "$out" "$src" >"$WORK/$i.log" 2>&1; then
        compiled=1
    else
        compiled=0
    fi

    case "$tag:$compiled" in
        must-compile:1|not-yet:0)
            pass=$((pass + 1))
            printf '  %-12s LANGUAGE.md:%s\n' "ok ($tag)" "$line"
            ;;
        must-compile:0)
            fail=$((fail + 1))
            printf '  %-12s LANGUAGE.md:%s  the reference shows something that does not compile\n' \
                   "BROKEN" "$line"
            FAILURES="$FAILURES $i"
            ;;
        not-yet:1)
            fail=$((fail + 1))
            printf '  %-12s LANGUAGE.md:%s  this COMPILES now -- drop the `not-yet` tag and update the prose\n' \
                   "PROMOTED" "$line"
            FAILURES="$FAILURES $i"
            ;;
        *)
            fail=$((fail + 1))
            printf '  %-12s LANGUAGE.md:%s  unknown tag "%s"\n' "BAD TAG" "$line" "$tag"
            FAILURES="$FAILURES $i"
            ;;
    esac
done

if [ "$VERBOSE" = 1 ] && [ -n "$FAILURES" ]; then
    for i in $FAILURES; do
        echo
        echo "=== block at LANGUAGE.md:$(cat "$WORK/$i.line") ==="
        cat "$WORK/$i.bs"
        echo "--- bsc said ---"
        cat "$WORK/$i.log"
    done
fi

echo
echo "$COUNT blocks: $pass ok, $fail wrong, $skipped illustrative"
[ "$fail" -eq 0 ] || {
    echo
    echo "Re-run with -v to see the source and the compiler's output."
    exit 1
}
