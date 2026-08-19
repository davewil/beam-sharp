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

    # NEGATIVE CONTROL — the reference as committed.
    if CHECK_LANGUAGE_DOC="$REPO/LANGUAGE.md" "${BASH_SOURCE[0]}" > /dev/null 2>&1
    then :; else
        echo "SELF-TEST FAILED: the reference as committed was rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the uncompilable block, the construct that has since"
        echo "           shipped and the unknown tag; accepted the committed reference"
        echo "           — the gate discriminates in both directions"
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
function flush_preamble() { pre = ""; }
/^<!-- check:/ { inpre = 1; pre = ""; next }
inpre && /^-->/ { inpre = 0; next }
inpre { pre = pre $0 "\n"; next }

/^```csharp/ {
    n++
    tag = $0
    sub(/^```csharp[ \t]*/, "", tag)
    if (tag == "") tag = "must-compile"
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
