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
# THE FOURTH CLAIM: WHAT THE COMPILER SAYS AFTER A NAMED EDIT (ENG-263)
#
#   <!-- expect-after: delete Classify(>= 9); delete Classify(0) -->
#   ```csharp
#   ...a block that compiles as written...
#   ```
#   ```
#   error: Classify is not exhaustive
#     no clause matches:
#   ...
#   ```
#
# The block compiles as written, like any untagged block. Then the named edits
# are applied to a copy and the compiler's output — minus the location prefix,
# since the block's file name is this script's — must equal the plain fence
# that follows. Until this existed the reference could show a residual only as
# prose or a comment, and two of its three residual displays had drifted: a
# bound the printer does not produce, and a line number from a file that does
# not exist. `delete <prefix>` and `replace <prefix> with <text>`, joined with
# `;`, each naming exactly one line — the same vocabulary `check-tour.sh` reads
# above its transcripts. `build-packet.py` strips the comment, so a worker sees
# the example and its answer as the spec has always shown them.
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

    # ------------------------------------------------------------------
    # CONTROLS 8-11 — the `expect-after` claim (ENG-263, 2026-09-02).
    #
    # A block that compiles and then, after a named edit, prints the fence
    # below it. The first control is the defect this was built from: §3 showed
    # `n <= 0` for a residual the compiler prints as `n <= -1`, and a line
    # number from a file that does not exist, for eighteen days.
    # ------------------------------------------------------------------
    after_block() {  # after_block FILE DIRECTIVE EXPECTED-THIRD-LINE
        {
            printf '\n<!-- expect-after: %s -->\n' "$2"
            printf '```csharp\n'
            printf 'module After%s\n' "$4"
            printf 'type Colour = :red | :amber | :green\n\n'
            printf 'public atom Go(Colour c)\n\n'
            printf 'Go(:red)   -> :stop\n'
            printf 'Go(:amber) -> :wait\n'
            printf 'Go(:green) -> :go\n'
            printf '```\n\n'
            if [ -n "$3" ]; then
                printf '```\n'
                printf 'error: Go is not exhaustive\n'
                printf '  no clause matches:\n'
                printf '%s\n' "$3"
                printf '```\n'
            fi
        } >> "$1"
    }

    # 8 — the fence shows a head the compiler does not print.
    cp "$REPO/LANGUAGE.md" "$CTL/afterdrift.md"
    after_block "$CTL/afterdrift.md" "delete Go(:green)" "    Go(:amber) -> ..." Drift
    expect "AFTER DRIFT" "$CTL/afterdrift.md" "a wrong output after an edit"

    # 9 — an edit naming a clause the block does not have.
    cp "$REPO/LANGUAGE.md" "$CTL/nosuchline.md"
    after_block "$CTL/nosuchline.md" "delete Go(:blue)" "    Go(:green) -> ..." NoLine
    expect "NO SUCH LINE" "$CTL/nosuchline.md" "an edit naming a line the block lacks"

    # 10 — a directive with no fence of expected output after the block.
    cp "$REPO/LANGUAGE.md" "$CTL/noexpected.md"
    after_block "$CTL/noexpected.md" "delete Go(:green)" "" NoFence
    expect "NO EXPECTED" "$CTL/noexpected.md" "a directive with nothing to compare against"

    # 11 — the correct form, which must be ACCEPTED. Same reason as the
    # `diagnoses:` positive control: three reds are also satisfied by a check
    # that rejects every directive it sees.
    cp "$REPO/LANGUAGE.md" "$CTL/aftergood.md"
    after_block "$CTL/aftergood.md" "delete Go(:green)" "    Go(:green) -> ..." Good
    if CHECK_LANGUAGE_DOC="$CTL/aftergood.md" "${BASH_SOURCE[0]}" > /dev/null 2>&1
    then :; else
        echo "SELF-TEST FAILED: a correct \`expect-after\` example was rejected, so this"
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
        echo "           and claimed twice; three ways an \`expect-after\` example can be"
        echo "           wrong — drifted, naming no line, showing no output; accepted a"
        echo "           correct one of each and the committed reference — the gate"
        echo "           discriminates in both directions"
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
function flush_preamble() { pre = ""; dg = ""; ea = ""; }
/^<!-- check:/ { inpre = 1; pre = ""; next }
inpre && /^-->/ { inpre = 0; next }
inpre { pre = pre $0 "\n"; next }

# `<!-- expect-after: edit; edit -->`. Binds to the fence below it like
# `diagnoses:`; the block must compile as written, and after the edits it must
# print the plain fence that FOLLOWS the block. Written to `<n>.edits`, and the
# expected text to `<n>.want` once that fence is read.
/^<!-- expect-after:/ {
    ea = $0
    sub(/^<!-- expect-after:[ \t]*/, "", ea)
    sub(/[ \t]*-->.*$/, "", ea)
    next
}

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
    # A previous block still waiting for its expected fence has lost it: the
    # judge reports NO EXPECTED for a `.edits` with no `.want`.
    wantfor = 0
    if (ea != "") { print ea > (out "/" n ".edits"); wantfor = n }
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
# The plain fence after an `expect-after` block is the output it expects.
inwant && /^```/ { printf "%s", want > (out "/" wantfor ".want"); inwant = 0; wantfor = 0; next }
inwant { want = want $0 "\n"; next }
wantfor && /^```/ { inwant = 1; want = ""; next }
{ if (!inpre) flush_preamble() }
END { print n > (out "/count") }
' "$DOC"

COUNT="$(cat "$WORK/count")"

pass=0; fail=0; skipped=0; mutated=0
FAILURES=""

# apply_edits ROOT TARGET EDITS — an `expect-after` directive, applied to a copy.
#
# The same reader `check-tour.sh` carries, and a copy rather than a shared file
# on purpose: `check-shell.sh` lints only executables and `check-gates-wired.sh`
# takes every executable for a gate, so a sourced helper would sit outside the
# one and inside the other. Two edits, joined with `;`:
#
#   delete <prefix>                 remove the one line that starts with <prefix>
#   replace <prefix> with <text>    rewrite that line's <prefix> as <text>
#
# A prefix is matched with runs of whitespace collapsed and must name EXACTLY
# ONE line. Prints the reason and returns 1 otherwise. Nothing here reaches a
# shell: the pieces go to awk as values.
apply_edits() {
    local root="$1" target="$2" edits="$3" edit mode prefix text files f n total hit
    if [ -d "$root/$target" ]; then
        files="$(find "$root/$target" -name '*.bs' | sort)"
    else
        files="$root/$target"
    fi
    while IFS= read -r edit; do
        edit="$(printf '%s' "$edit" | sed 's/^ *//; s/ *$//')"
        [ -n "$edit" ] || continue
        case "$edit" in
            'delete '*)
                mode=delete; prefix="${edit#delete }"; text="" ;;
            'replace '*)
                mode=replace; prefix="${edit#replace }"
                case "$prefix" in
                    *' with '*) text="${prefix##* with }"; prefix="${prefix% with *}" ;;
                    *) echo "BAD EDIT  '$edit' — replace needs 'with'"; return 1 ;;
                esac ;;
            *)  echo "BAD EDIT  '$edit' — only 'delete <prefix>' and 'replace <prefix> with <text>' exist"
                return 1 ;;
        esac
        prefix="$(printf '%s' "$prefix" | tr -s '[:blank:]' ' ')"
        total=0; hit=""
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            n="$(awk -v p="$prefix" 'BEGIN { c = 0 }
                { l = $0; gsub(/[ \t]+/, " ", l); sub(/^ /, "", l); if (index(l, p) == 1) c++ }
                END { print c }' "$f")"
            if [ "$n" -gt 0 ]; then total=$((total + n)); hit="$f"; fi
        done <<< "$files"
        if [ "$total" -eq 0 ]; then
            echo "NO SUCH LINE  '$edit' — no line of the block starts with '$prefix'"
            return 1
        elif [ "$total" -gt 1 ]; then
            echo "AMBIGUOUS  '$edit' — $total lines of the block start with '$prefix'"
            return 1
        fi
        awk -v p="$prefix" -v r="$text" -v m="$mode" '
            { l = $0; gsub(/[ \t]+/, " ", l); sub(/^ /, "", l)
              if (index(l, p) == 1) {
                  if (m == "delete") next
                  print r substr(l, length(p) + 1); next
              }
              print }' "$hit" > "$hit.tmp" && mv "$hit.tmp" "$hit"
    done <<< "$(printf '%s' "$edits" | tr ';' '\n')"
    return 0
}

# judge_after I LINE SRC — the block compiled; now apply its edits to a copy and
# compare what the compiler says with the fence the document shows.
#
# The location prefix (`…/12.bs:4: `) is dropped from what the compiler prints
# before comparing, because the block's file name is this script's and not the
# reader's; the text from `error:` on is compared byte for byte.
judge_after() {
    local i="$1" line="$2" src="$3" edits rel after out2 reason got want
    edits="$(cat "$WORK/$i.edits")"
    if [ ! -f "$WORK/$i.want" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  `expect-after` names an edit, but no plain fence follows the block with the output it expects\n' \
               "NO EXPECTED" "$line"
        FAILURES="$FAILURES $i"
        return 0
    fi
    rel="${src#"$WORK/b$i/"}"
    after="$WORK/a$i"
    rm -rf "$after"; mkdir -p "$after"
    cp -R "$WORK/b$i" "$after/b"
    if ! reason="$(apply_edits "$after/b" "$rel" "$edits")"; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  %s\n' "BAD EDIT" "$line" "$reason"
        FAILURES="$FAILURES $i"
        return 0
    fi
    out2="$WORK/aout$i"; mkdir -p "$out2"
    "$BSC" --src-root "$after/b" -o "$out2" "$after/b/$rel" > "$WORK/$i.after" 2>&1 || true
    got="$(sed 's/^[^ ]*\.bs:[0-9][0-9]*: //' "$WORK/$i.after")"
    want="$(cat "$WORK/$i.want")"
    if [ "$got" = "$want" ]; then
        mutated=$((mutated + 1))
        printf '  %-12s LANGUAGE.md:%s  after: %s\n' "ok (after)" "$line" "$edits"
    else
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  after `%s` the compiler does not print the fence shown\n' \
               "AFTER DRIFT" "$line" "$edits"
        printf '%s\n' "$want" | sed 's/^/                 shown:   /'
        printf '%s\n' "$got"  | sed 's/^/                 prints:  /'
        FAILURES="$FAILURES $i"
    fi
}

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

    # The fourth claim. Only a block that compiled as written is edited: a
    # BROKEN block has already been reported, and editing it proves nothing.
    if [ -f "$WORK/$i.edits" ] && [ "$tag" = "must-compile" ] && [ "$compiled" -eq 1 ]; then
        judge_after "$i" "$line" "$src"
    elif [ -f "$WORK/$i.edits" ] && [ "$tag" != "must-compile" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  `expect-after` belongs on an untagged block that compiles, not a `%s` one\n' \
               "BAD TAG" "$line" "$tag"
        FAILURES="$FAILURES $i"
    fi
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
echo "$COUNT blocks: $pass ok, $fail wrong, $skipped illustrative; $mutated replayed after an edit"
[ "$fail" -eq 0 ] || {
    echo
    echo "Re-run with -v to see the source and the compiler's output."
    exit 1
}
