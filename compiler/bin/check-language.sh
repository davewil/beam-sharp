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

    # ------------------------------------------------------------------
    # THE CONTROLS RUN AT ONCE, AND EACH VERDICT IS READ FROM ITS OWN FILE
    # (ENG-315, 2026-09-03).
    #
    # A control is this whole gate over the whole reference, and the gate
    # booted one VM per fenced block until ENG-314 landed the same day, so
    # fifteen controls over fifty-odd blocks ran for 321s on the CI runner —
    # with check-tour.sh's, 65% of the job. Each control is one VM now (see
    # the batch below the self-test), and they still run at once because
    # fifteen sequential boots of the compiler are still fifteen boots. The
    # controls share nothing: each reads its own copy of the
    # document under $CTL and the gate writes under a scratch of its own.
    # So a control is built here, launched in the background by `launch`,
    # and only QUEUED for judgement by `expect` or `accept`; after `wait`
    # the loop at the end reads every control's captured output and exit
    # status back from `$CTL/<name>.out` and `.status`. A control that
    # never wrote its status is red, never green.
    #
    # THE VERDICT COMES FROM THE FILES, NOT FROM THE LAUNCHER. The old
    # `control` helper ended in `|| true` so a failing run's output could
    # be read under `pipefail`, and the negative control that read its
    # exit status through that helper passed for as long as it was written
    # that way (check-tour.sh, found 2026-09-02). Here nothing reads the
    # launcher's status at all.
    #
    # Bash 3.2 as well as 5: `wait -n` is 4.3+, so a bare `wait` collects
    # every job and the files carry the results.
    #
    # EACH RUN GETS ITS OWN TMPDIR. `bsc` names its scratch directory under
    # $TMPDIR from `erlang:unique_integer`, which is unique within one VM
    # and repeats across VMs — 12 distinct values from 30 fresh VMs when
    # measured on 2026-09-03 — so two concurrent runs of a gate could share
    # one `.beam` path. Every `bsc` call in this gate passes `-o`, so here
    # it is a precaution; in check-tour.sh's plain replays it is the race.
    # ------------------------------------------------------------------
    launch() {   # launch <name> [VAR=value ...] — this gate, in the background
        local name="$1"; shift
        mkdir -p "$CTL/$name.tmp"
        (
            rc=0
            env TMPDIR="$CTL/$name.tmp" "$@" "${BASH_SOURCE[0]}" \
                > "$CTL/$name.out" 2>&1 || rc=$?
            echo "$rc" > "$CTL/$name.status"
        ) &
    }
    doc() {      # doc <name> — launch over $CTL/<name>.md
        launch "$1" CHECK_LANGUAGE_DOC="$CTL/$1.md"
    }

    queued=0
    expect() {   # expect <marker> <name> <what the control built> — judged after wait
        MARK[$queued]="$1"; NAME[$queued]="$2"; WHAT[$queued]="$3"
        queued=$((queued + 1))
    }
    accept() {   # accept <name> <why a rejection is wrong> — must exit 0
        MARK[$queued]=""; NAME[$queued]="$1"; WHAT[$queued]="$2"
        queued=$((queued + 1))
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
    doc broken
    expect "BROKEN" broken "an untagged block that does not compile"

    # CONTROL 2 — a block still marked planned that the compiler now accepts.
    cp "$REPO/LANGUAGE.md" "$CTL/promoted.md"
    {
        printf '\n```csharp not-yet\n'
        printf 'public int Twice(int n)\n'
        printf 'Twice(n) -> n * 2\n'
        printf '```\n'
    } >> "$CTL/promoted.md"
    doc promoted
    expect "PROMOTED" promoted "a shipped construct still tagged not-yet"

    # CONTROL 3 — a tag nothing knows. It must be an error, not a quiet skip.
    cp "$REPO/LANGUAGE.md" "$CTL/badtag.md"
    {
        printf '\n```csharp probably\n'
        printf 'public int Twice(int n)\n'
        printf 'Twice(n) -> n * 2\n'
        printf '```\n'
    } >> "$CTL/badtag.md"
    doc badtag
    expect "BAD TAG" badtag "an unknown fence tag"

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
    doc silent
    expect "WRONG DIAG" silent "an example that provokes no diagnostic at all"

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
    doc wrongtag
    expect "WRONG DIAG" wrongtag "an example that provokes a different diagnostic"

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
    doc superset
    expect "WRONG DIAG" superset "an example carrying a second, unrelated diagnostic"

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
    doc twoclaims
    expect "BAD TAG" twoclaims "a block carrying two different claims"

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
    doc good
    accept good "a correct \`diagnoses:\` example was rejected, so this
                  check fires on the defect and the correct form alike"

    # ------------------------------------------------------------------
    # CONTROLS 8-13 — the `expect-after` claim (ENG-263, 2026-09-02).
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
    doc afterdrift
    expect "AFTER DRIFT" afterdrift "a wrong output after an edit"

    # 9 — an edit naming a clause the block does not have.
    cp "$REPO/LANGUAGE.md" "$CTL/nosuchline.md"
    after_block "$CTL/nosuchline.md" "delete Go(:blue)" "    Go(:green) -> ..." NoLine
    doc nosuchline
    expect "NO SUCH LINE" nosuchline "an edit naming a line the block lacks"

    # 10 — a directive with no fence of expected output after the block.
    cp "$REPO/LANGUAGE.md" "$CTL/noexpected.md"
    after_block "$CTL/noexpected.md" "delete Go(:green)" "" NoFence
    doc noexpected
    expect "NO EXPECTED" noexpected "a directive with nothing to compare against"

    # 11 — the correct form, which must be ACCEPTED. Same reason as the
    # `diagnoses:` positive control: three reds are also satisfied by a check
    # that rejects every directive it sees.
    cp "$REPO/LANGUAGE.md" "$CTL/aftergood.md"
    after_block "$CTL/aftergood.md" "delete Go(:green)" "    Go(:green) -> ..." Good
    doc aftergood
    accept aftergood "a correct \`expect-after\` example was rejected, so this
                  check fires on the defect and the correct form alike"

    # 12 — both production directives removed. Ordinary blocks still compile,
    # so without a floor the summary quietly says `0 replayed after an edit`
    # and exits green: the mutation half of the reference has disappeared.
    sed '/^<!-- expect-after:/d' "$REPO/LANGUAGE.md" > "$CTL/noafter.md"
    doc noafter
    expect "TOO FEW" noafter "a reference with no expect-after directives"

    # 13 — one of the two production displays removed. This distinguishes the
    # committed floor from a weaker `mutated > 0` check.
    awk '!removed && /^<!-- expect-after:/ { removed = 1; next } { print }' \
        "$REPO/LANGUAGE.md" > "$CTL/oneafter.md"
    doc oneafter
    expect "TOO FEW" oneafter "a reference with only one expect-after directive"

    # NEGATIVE CONTROL — the reference as committed.
    launch committed CHECK_LANGUAGE_DOC="$REPO/LANGUAGE.md"
    accept committed "the reference as committed was rejected, so this gate
                  would fail every clean tree and be removed"

    # ------------------------------------------------------------------
    # Every control is running. Collect them all, then judge each from what
    # it wrote. Nothing below reads `$?` of a run.
    # ------------------------------------------------------------------
    wait

    st_fail=0
    i=0
    while [ "$i" -lt "$queued" ]; do
        out="$(cat "$CTL/${NAME[$i]}.out" 2>/dev/null || true)"
        status="$(cat "$CTL/${NAME[$i]}.status" 2>/dev/null || echo "never wrote one")"
        if [ -n "${MARK[$i]}" ]; then
            case "$out" in
                *"${MARK[$i]}"*) ;;
                *) echo "SELF-TEST FAILED: ${WHAT[$i]} was not reported — the ${MARK[$i]} check cannot fire"
                   st_fail=1 ;;
            esac
        elif [ "$status" != "0" ]; then
            echo "SELF-TEST FAILED: ${WHAT[$i]}"
            echo "                  (exit status: $status)"
            st_fail=1
        fi
        i=$((i + 1))
    done

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the uncompilable block, the construct that has since"
        echo "           shipped, the unknown tag, and four ways a \`diagnoses:\` example"
        echo "           can be wrong — silent, mislabelled, carrying a second diagnostic,"
        echo "           and claimed twice; four ways an \`expect-after\` example can be"
        echo "           wrong — drifted, naming no line, showing no output, or too few"
        echo "           production displays remaining; accepted a"
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
# LANGUAGE.md carried two verified diagnostic displays when `expect-after`
# landed. Fewer means a display stopped being parsed or lost its directive;
# ordinary compilation alone cannot reveal that loss.
EXPECT_AFTER_FLOOR=2
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

# --- one VM for every block (ENG-314, 2026-09-03) -----------------------------
#
# Each block used to be its own `bsc` process, and a `bsc` process is a VM
# boot; fifty-odd blocks, times the fifteen controls in the self-test, was 321s
# on the CI runner. So the run is three passes now. The first writes every
# block's invocation into one manifest — one `arg` line per argument, so
# nothing is quoted and nothing is re-parsed — and `bsc --batch` runs them all
# in one VM, writing each block's stdout, stderr, merged output and exit status
# to `$WORK/r1/b<n>.*`. The second queues the `expect-after` replays, which can
# only be built once the first pass says which blocks compiled, and runs them
# as a second batch. The third judges every block in document order from the
# files, printing exactly what the per-process loop printed.
#
# A BLOCK WITH NO STATUS FILE IS RED. The batch writes all four files for every
# entry or refuses the whole manifest before running any, so a missing verdict
# means the batch itself did not run — and `run_batch` says so and stops rather
# than letting a loop over nothing report `0 wrong`.
manifest_entry() {   # manifest_entry MANIFEST ID ARG... — one entry, one argument per line
    local f="$1" id="$2" a
    shift 2
    {
        printf 'entry %s\n' "$id"
        for a in "$@"; do printf 'arg %s\n' "$a"; done
        printf 'end\n\n'
    } >> "$f"
}

run_batch() {        # run_batch MANIFEST RESULTS — every entry, one VM
    [ -s "$1" ] || return 0
    if ! "$BSC" --batch "$1" "$2" > "$2.log" 2>&1; then
        echo "  BATCH FAILED  bsc --batch could not run the blocks, so nothing below was judged"
        sed 's/^/                /' "$2.log"
        return 1
    fi
}

status_of() {        # status_of RESULTS ID — the exit status, or `none`
    cat "$1/$2.status" 2>/dev/null || echo none
}

# Pass 1 — every block that is checked at all, into one manifest.
for i in $(seq 1 "$COUNT"); do
    tag="$(cat "$WORK/$i.tag")"
    [ "$tag" = "illustrative" ] && continue

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
    printf '%s' "$src" > "$WORK/$i.src"

    # A `diagnoses:` block is judged on WHAT THE COMPILER PUBLISHED, not on
    # whether it compiled. `unreachable_arm` is a warning, so its example
    # compiles and still carries the diagnostic the prose is about; an exit
    # status cannot tell those two situations apart.
    #
    # `--diagnostics term` and the extraction in pass 3 are `oracle.sh`'s,
    # deliberately: the audition's expectations and the reference's examples
    # then agree because they are read off the same public output, rather than
    # because two authors believed the same thing on two different days.
    case "$tag" in
    diagnoses:*)
        manifest_entry "$WORK/m1" "b$i" --diagnostics term \
            --src-root "$WORK/b$i" -o "$out" "$src" ;;
    *)
        manifest_entry "$WORK/m1" "b$i" --src-root "$WORK/b$i" -o "$out" "$src" ;;
    esac
done

run_batch "$WORK/m1" "$WORK/r1" || exit 1

# Pass 2 — the `expect-after` replays. Only a block that compiled as written is
# edited: a BROKEN block has already been reported, and editing it proves
# nothing. An edit that cannot be applied is recorded here and reported in
# pass 3, where the block's other lines are.
for i in $(seq 1 "$COUNT"); do
    [ -f "$WORK/$i.edits" ] || continue
    [ "$(cat "$WORK/$i.tag")" = "must-compile" ] || continue
    [ "$(status_of "$WORK/r1" "b$i")" = "0" ] || continue
    [ -f "$WORK/$i.want" ] || continue
    src="$(cat "$WORK/$i.src")"
    rel="${src#"$WORK/b$i/"}"
    after="$WORK/a$i"
    rm -rf "$after"; mkdir -p "$after"
    cp -R "$WORK/b$i" "$after/b"
    if ! reason="$(apply_edits "$after/b" "$rel" "$(cat "$WORK/$i.edits")")"; then
        printf '%s' "$reason" > "$WORK/$i.badedit"
        continue
    fi
    mkdir -p "$WORK/aout$i"
    manifest_entry "$WORK/m2" "a$i" --src-root "$after/b" -o "$WORK/aout$i" "$after/b/$rel"
done

run_batch "$WORK/m2" "$WORK/r2" || exit 1

# judge_after I LINE — the block compiled and its edited copy has been replayed;
# compare what the compiler said with the fence the document shows.
#
# The location prefix (`…/12.bs:4: `) is dropped from what the compiler prints
# before comparing, because the block's file name is this script's and not the
# reader's; the text from `error:` on is compared byte for byte.
judge_after() {
    local i="$1" line="$2" edits got want
    edits="$(cat "$WORK/$i.edits")"
    if [ ! -f "$WORK/$i.want" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  `expect-after` names an edit, but no plain fence follows the block with the output it expects\n' \
               "NO EXPECTED" "$line"
        FAILURES="$FAILURES $i"
        return 0
    fi
    if [ -f "$WORK/$i.badedit" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  %s\n' "BAD EDIT" "$line" "$(cat "$WORK/$i.badedit")"
        FAILURES="$FAILURES $i"
        return 0
    fi
    if [ "$(status_of "$WORK/r2" "a$i")" = "none" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  the batch wrote no verdict for the edited replay\n' \
               "NO RESULT" "$line"
        FAILURES="$FAILURES $i"
        return 0
    fi
    got="$(sed 's/^[^ ]*\.bs:[0-9][0-9]*: //' "$WORK/r2/a$i.output")"
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

# Pass 3 — the verdicts, in document order, from what the batch wrote.
for i in $(seq 1 "$COUNT"); do
    tag="$(cat "$WORK/$i.tag")"
    line="$(cat "$WORK/$i.line")"

    if [ "$tag" = "illustrative" ]; then
        skipped=$((skipped + 1))
        printf '  %-12s LANGUAGE.md:%s\n' "skipped" "$line"
        continue
    fi

    status="$(status_of "$WORK/r1" "b$i")"
    if [ "$status" = "none" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  the batch wrote no verdict for this block\n' \
               "NO RESULT" "$line"
        FAILURES="$FAILURES $i"
        continue
    fi

    case "$tag" in
    diagnoses:*)
        want="${tag#diagnoses:}"
        # The term went to stdout and the prose to stderr, as `2>/dev/null` once
        # kept them apart; only the stdout file is read.
        got="$(sed -n 's/.*tag => \([a-z_][a-z_0-9]*\).*/\1/p' "$WORK/r1/b$i.stdout" | sort -u | tr '\n' ' ')"
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

    if [ "$status" = "0" ]; then compiled=1; else compiled=0; fi

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

    # The fourth claim.
    if [ -f "$WORK/$i.edits" ] && [ "$tag" = "must-compile" ] && [ "$compiled" -eq 1 ]; then
        judge_after "$i" "$line"
    elif [ -f "$WORK/$i.edits" ] && [ "$tag" != "must-compile" ]; then
        fail=$((fail + 1))
        printf '  %-12s LANGUAGE.md:%s  `expect-after` belongs on an untagged block that compiles, not a `%s` one\n' \
               "BAD TAG" "$line" "$tag"
        FAILURES="$FAILURES $i"
    fi
done

if [ "$fail" -eq 0 ] && [ "$mutated" -lt "$EXPECT_AFTER_FLOOR" ]; then
    echo
    echo "  TOO FEW      $mutated blocks replayed after an edit; the reference had $EXPECT_AFTER_FLOOR"
    echo "               on 2026-09-02. A directive stopped being read or a display"
    echo "               lost its edit — lower the floor only if one was removed on purpose."
    fail=$((fail + 1))
fi

if [ "$VERBOSE" = 1 ] && [ -n "$FAILURES" ]; then
    for i in $FAILURES; do
        echo
        echo "=== block at LANGUAGE.md:$(cat "$WORK/$i.line") ==="
        cat "$WORK/$i.bs"
        echo "--- bsc said ---"
        cat "$WORK/r1/b$i.output"
    done
fi

echo
echo "$COUNT blocks: $pass ok, $fail wrong, $skipped illustrative; $mutated replayed after an edit"
[ "$fail" -eq 0 ] || {
    echo
    echo "Re-run with -v to see the source and the compiler's output."
    exit 1
}
