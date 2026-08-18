#!/usr/bin/env bash
#
# TOUR.md quotes the corpus. This proves it still does.
#
# WHY THIS EXISTS
# `bin/check-language.sh` compiles LANGUAGE.md's blocks, so that document cannot
# drift from the compiler. TOUR.md's blocks are EXCERPTS — a handful of clauses
# lifted out of a file, without the signature or the module line above them — so
# they do not compile on their own and that gate cannot reach them. The failure
# mode is therefore different and quieter: not a block that stops compiling, but
# a block that still reads plausibly while the file it claims to quote has moved
# on. A tour whose code is nearly the corpus is worse than no tour, because a
# reader has no way to tell which lines are the stale ones.
#
# WHAT IT CHECKS
# Every non-blank, non-comment, non-elision line inside a fenced block in TOUR.md
# appears VERBATIM somewhere under `compiler/examples/`. Shell transcripts
# (blocks whose first line starts with `$ `) and non-B# fences are skipped.
#
# WHAT IT DOES NOT CHECK
# That a line was quoted from the file the prose NAMES, or that the lines of a
# block are contiguous, or in order. `bin/check-links.sh` covers the paths
# themselves. A line moving from one example to another passes here — the same
# tolerance `check-tokens.sh` has, and for the same reason: this gate proves the
# text is real, never that the sentence around it is right.
#
# THE ONE TOLERANCE, and it was earned on this gate's first run. A corpus
# COMMENT counts as corpus text: the `//` and its indent are stripped before
# matching. Without that the two prelude aliases the tour shows —
# `type option<T> = T | :nothing` and its `result` sibling — were reported as
# invented, and they are not. They are written out verbatim in `parcel.bs`'s
# header, because the prelude is the one part of the language that is real code
# a user could have written and yet appears in no `.bs` file as code. The
# alternative was to let that block go untagged and ungated, which is the exact
# hole this script exists to close.
#
# Usage:  compiler/bin/check-tour.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$REPO/TOUR.md"
CORPUS="$REPO/compiler/examples"

[ -f "$DOC" ] || { echo "no TOUR.md at $DOC" >&2; exit 2; }
[ -d "$CORPUS" ] || { echo "no corpus at $CORPUS" >&2; exit 2; }

# One flattened copy of every example, so a line is checked with one grep.
ALL="$(mktemp)"
RAW="$(mktemp)"
trap 'rm -f "$ALL" "$RAW"' EXIT
find "$CORPUS" -name '*.bs' -exec cat {} + > "$RAW"
# Comment text counts — see the tolerance above. Both spellings of a commented
# line go into the haystack, so a quote matches whichever way it was written.
# Two files rather than one appended to itself: reading and writing the same
# path in one pipeline is undefined, and shellcheck says so at `info`, which is
# the level `bin/check-shell.sh` runs these at.
cat "$RAW" > "$ALL"
sed -n 's|^ *// \{0,3\}||p' "$RAW" >> "$ALL"

echo
echo "lines TOUR.md quotes from the corpus"
echo

fail=0
checked=0

# `in_block` tracks the fence; `skip` marks a transcript or a non-B# fence.
in_block=0
skip=0
lineno=0

while IFS= read -r line; do
    lineno=$((lineno + 1))

    case "$line" in
        '```'*)
            if [ "$in_block" -eq 1 ]; then
                in_block=0; skip=0
            else
                in_block=1; skip=0
                # A fence with a language tag is prose, not corpus.
                [ "$line" != '```' ] && skip=1
            fi
            continue
            ;;
    esac

    [ "$in_block" -eq 1 ] || continue
    [ "$skip" -eq 1 ] && continue

    # A transcript line, and everything after it in this block, is output.
    case "$line" in
        '$ '*) skip=1; continue ;;
    esac

    # Blank, comment, and the elision marker prose uses between clauses.
    [ -n "${line// /}" ] || continue
    case "$line" in
        '//'*|' '*'//'*) continue ;;
        '...'|'…') continue ;;
    esac

    checked=$((checked + 1))
    if ! grep -qxF "$line" "$ALL"; then
        echo "  NOT IN CORPUS  TOUR.md:$lineno"
        echo "                 $line"
        fail=1
    fi
done < "$DOC"

if [ "$fail" -eq 0 ]; then
    printf '  %-9s %d lines, every one verbatim in compiler/examples/\n' "ok" "$checked"
else
    echo
    echo "TOUR.md quotes lines the corpus does not contain."
fi

# --- 2: the tour meets every capability the corpus gate names ----------------
#
# `corpus_tests:demonstrated_surface/0` is the list of capabilities that owe an
# example, and it fails BY NAME when a shipped form has nothing to look at. The
# tour claims to walk all of them, so the two lists are diffed here rather than
# by eye — and the appendix carries the gate's own wording so that a diff is
# possible at all.
#
# This is the check that makes "every construct" a proven claim. Without it the
# appendix is a promise, and the next capability added to the roster ships with
# the tour silently one short.
ROSTER="$REPO/compiler/test/corpus_tests.erl"

echo
echo "capabilities the corpus gate names, and the tour's appendix"
echo

missing=0
named=0
while IFS= read -r cap; do
    [ -n "$cap" ] || continue
    named=$((named + 1))
    if ! grep -qF "| $cap |" "$DOC"; then
        echo "  NOT IN TOUR    $cap"
        missing=1; fail=1
    fi
done < <(awk '/^demonstrated_surface\(\) ->/,/^\]\./' "$ROSTER" |
         grep -oE '\{"[^"]*"' | sed 's/[{"]//g')

if [ "$named" -eq 0 ]; then
    echo "  read no capabilities from $ROSTER — the roster moved" >&2
    exit 2
fi
[ "$missing" -eq 0 ] &&
    printf '  %-9s all %d appear in the appendix\n' "ok" "$named"

# --- 3: the transcripts still print what they say they print -----------------
#
# Part 1 covers the B#; this covers the shell. Roughly forty `$ bsc …` lines
# carry pasted output, and without this they are the ungated half of a document
# whose whole pitch is that it cannot drift.
#
# A transcript showing a DIAGNOSTIC is skipped, and the reason is in the prose
# beside it: those were produced by editing a corpus file in place, so replaying
# the command against clean sources would correctly print nothing. Skipping is
# named in the output rather than silent — `bin/check-no-silent-skip.sh` exists
# because a check that says `ok` for work it did not do is not a check.
BSC="$REPO/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || {
    echo "no escript at $BSC — run \`rebar3 escriptize\` in compiler/ first" >&2
    exit 2
}

echo
echo "transcripts TOUR.md pastes"
echo

replayed=0
drifted=0
skipped=0
cmd=""
want=""
in_block=0

# SPLITTING A COMMAND LINE WITHOUT A SHELL, AND WHY IT IS WORTH THE LINES.
#
# The first draft ran `eval` on the command string it had just read out of
# TOUR.md, because the arguments carry quotes — `Classify '(:ok, 5)'` — and
# `eval` is the one-liner that honours them. It is also arbitrary code
# execution from a file in the repository, and this workflow runs on
# `pull_request`, so a line added to a markdown document would have executed in
# CI. A security review of the pushed commits caught it.
#
# So the quotes are honoured here instead, by a reader that understands exactly
# two things — single quotes, and double quotes with backslash escapes — and
# performs no expansion of any kind. A `;` or a `$(…)` in TOUR.md now reaches
# `bsc` as an ordinary argument, which is the correct outcome: the gate is
# meant to run the compiler, and nothing else.
#
# Fills the global `ARGV`. An empty quoted argument would be dropped; nothing
# in the document has one, and adding the flag to track it would be the only
# state this reader needs beyond the character it is looking at.
split_command() {
    local s="$1" tok="" quote="" c esc=0 i
    ARGV=()
    for (( i = 0; i < ${#s}; i++ )); do
        c="${s:i:1}"
        if [ "$esc" -eq 1 ]; then
            tok+="$c"; esc=0
        elif [ "$quote" = '"' ] && [ "$c" = '\' ]; then
            esc=1
        elif [ -n "$quote" ]; then
            if [ "$c" = "$quote" ]; then quote=""; else tok+="$c"; fi
        elif [ "$c" = "'" ] || [ "$c" = '"' ]; then
            quote="$c"
        elif [ "$c" = " " ]; then
            [ -n "$tok" ] && { ARGV+=("$tok"); tok=""; }
        else
            tok+="$c"
        fi
    done
    [ -n "$tok" ] && ARGV+=("$tok")
    [ -z "$quote" ]
}

replay() {
    [ -n "$cmd" ] || return 0
    # A diagnostic transcript needs an edit the prose describes; see above.
    case "$want" in
        examples/*:[0-9]*|'#{'*|'error: '*)
            skipped=$((skipped + 1)); return 0 ;;
    esac
    replayed=$((replayed + 1))

    if ! split_command "$cmd"; then
        echo "  UNBALANCED QUOTE  \$ $cmd"
        drifted=1; fail=1
        return 0
    fi

    local got
    # ARGV[0] is the literal `bsc` the document writes; the escript is under
    # _build. Everything after it is passed as an argument vector, never as a
    # string a shell gets to look at again.
    got="$(cd "$REPO/compiler" && "$BSC" "${ARGV[@]:1}" 2>&1)" || true
    if [ "$got" != "$want" ]; then
        echo "  DRIFTED   \$ $cmd"
        echo "    pasted:  $want"
        echo "    prints:  $got"
        drifted=1; fail=1
    fi
}

while IFS= read -r line; do
    case "$line" in
        '```'*)
            [ "$in_block" -eq 1 ] && { replay; cmd=""; want=""; }
            in_block=$((1 - in_block))
            continue
            ;;
    esac
    [ "$in_block" -eq 1 ] || continue

    case "$line" in
        '$ bsc '*)
            replay
            cmd="${line#$ }"; want=""
            ;;
        '$ '*)
            # Some other command — `cd`, `rebar3`, the `erl` spec dump. Not this
            # gate's business, and it ends whatever transcript preceded it.
            replay; cmd=""; want=""
            ;;
        *)
            [ -n "$cmd" ] || continue
            if [ -z "$want" ]; then want="$line"; else want="$want
$line"; fi
            ;;
    esac
done < "$DOC"
replay

# The verdict word is computed, not written. An earlier draft printed `ok`
# unconditionally under the DRIFTED lines it had just emitted, which is the
# same class of defect as a gate that returns success for work it did not do.
if [ "$drifted" -eq 0 ]; then
    printf '  %-9s %d commands replayed, %d diagnostics skipped (they need an edit)\n' \
        "ok" "$replayed" "$skipped"
else
    echo
    echo "TOUR.md pastes output the compiler no longer produces."
fi

echo
exit "$fail"
