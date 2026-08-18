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

echo
exit "$fail"
