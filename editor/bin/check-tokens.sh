#!/usr/bin/env bash
#
# Every keyword the lexer defines must appear in both editor grammars.
#
# WHY THIS EXISTS
# `compiler/src/bs_lexer.xrl` is the source of truth for the surface's tokens,
# and the two grammars here are a hand-written second copy of part of it. This
# repo designs duplicate sources of truth away where it can -- `resolve/2` is
# exported so the checker and the emitter do not have two resolvers, and
# `qualified/2` is "THE SINGLE MINTING POINT" -- but a TextMate grammar cannot be
# derived from a leex file, so the copy is unavoidable and the drift is not.
#
# WHAT IT CHECKS, AND WHAT IT DOES NOT
# Keywords and the two arrows, which are what a new feature adds. It does NOT
# check that the grammars are CORRECT -- a rule can be present and wrong, and
# only looking at a coloured file catches that. F7 is the case in point: it added
# `switch`, `=>`, and the two keyword atoms, and this gate would have named all
# four.
#
# Usage:  editor/bin/check-tokens.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

LEXER="$REPO/compiler/src/bs_lexer.xrl"
TM="$HERE/vscode/syntaxes/beam-sharp.tmLanguage.json"
VIM="$HERE/nvim/syntax/bs.vim"

for f in "$LEXER" "$TM" "$VIM"; do
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 2; }
done

# A keyword rule in leex is a bare lowercase word in the first column followed by
# the token action. Every other rule starts with a sigil, a brace or `_`, so this
# picks out exactly the words and nothing else.
KEYWORDS="$(grep -oE '^[a-z]+[[:space:]]+:[[:space:]]*\{token,' "$LEXER" \
            | sed -E 's/[[:space:]]*:.*//' | sort -u)"

fail=0

for kw in $KEYWORDS; do
    in_tm=0; in_vim=0
    grep -q "\\b$kw\\b" "$TM"  && in_tm=1
    grep -q "\\b$kw\\b" "$VIM" && in_vim=1

    if [ "$in_tm" = 1 ] && [ "$in_vim" = 1 ]; then
        printf '  %-10s %s\n' "ok" "$kw"
    else
        missing=""
        [ "$in_tm" = 0 ]  && missing="$missing vscode"
        [ "$in_vim" = 0 ] && missing="$missing nvim"
        printf '  %-10s %s  -- missing from:%s\n' "MISSING" "$kw" "$missing"
        fail=1
    fi
done

# The two arrows are the pair most likely to be added one at a time: `->` has
# been there since the walking skeleton and `=>` arrived with F7.
for arrow in '\->' '=>'; do
    if grep -q -- "$arrow" "$TM" && grep -q -- "$arrow" "$VIM"; then
        printf '  %-10s %s\n' "ok" "${arrow#\\}"
    else
        printf '  %-10s %s  -- an arrow the lexer has and a grammar does not\n' \
               "MISSING" "${arrow#\\}"
        fail=1
    fi
done

echo
if [ "$fail" -eq 0 ]; then
    echo "$(echo "$KEYWORDS" | wc -w | tr -d ' ') keywords + 2 arrows: all present in both grammars"
else
    echo "a token the lexer defines has no rule in one of the editor grammars."
    exit 1
fi
